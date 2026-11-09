CREATE PROCEDURE [mgmt_xtinfra].[infra_migration_hash_calculation]
    @run_mode [VARCHAR](7)
AS
BEGIN
    DECLARE @sql            NVARCHAR(MAX);
    DECLARE @col_query      NVARCHAR(MAX);
    DECLARE @checksum_cols  NVARCHAR(MAX);
    DECLARE @schema_name    NVARCHAR(128);
    DECLARE @table_name     NVARCHAR(128);
    DECLARE @object_id      INT;
    DECLARE @current_id     INT = 1;
    DECLARE @total_tables   INT;
    DECLARE @hash_value     VARCHAR(100);

    IF (@run_mode NOT IN ('SYNAPSE', 'FABRIC'))
        THROW 50500, 'run_mode can only be SYNAPSE or FABRIC', 5;

    IF (@run_mode = 'SYNAPSE')
        TRUNCATE TABLE [mgmt_xtinfra].[infra_migration_validation_hashes];

    -- 2. Get the list of tables
    IF OBJECT_ID('tempdb..#TablesToHash') IS NOT NULL
        DROP TABLE #TablesToHash;

    CREATE TABLE #TablesToHash (
        [row_num] INT,
        [schema_name] VARCHAR(128),
        [table_name] VARCHAR(128),
        [object_id] INT
    );

    INSERT INTO #TablesToHash
    SELECT
        ROW_NUMBER() OVER(ORDER BY s.name, t.name) AS row_num,
        CAST(s.name AS varchar(128)) AS schema_name,
        CAST(t.name AS varchar(128)) AS table_name,
        t.object_id
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.is_external = 0
      AND t.is_ms_shipped = 0
      AND t.name <> 'infra_migration_validation_hashes';

    SELECT @total_tables = COUNT(*) FROM #TablesToHash;

    -- 3. Loop through and calculate/insert the hashes
    WHILE @current_id <= @total_tables
    BEGIN
        SELECT
            @schema_name = schema_name,
            @table_name = table_name,
            @object_id = object_id
        FROM #TablesToHash
        WHERE row_num = @current_id;

        -- Generate the explicit CAST columns using the PERFECTED decoupled logic
        SET @col_query = N'
            SELECT @out_cols = STRING_AGG(
                CAST(
                    ''CAST(BINARY_CHECKSUM('' +
                    CASE
                        -- STRINGS: VARCHAR(8000) bypasses LOB hashing, ISNULL fixes Parquet empty strings, REPLACE fixes line endings
                        WHEN ty.name IN (''varchar'', ''char'', ''nvarchar'', ''nchar'', ''sysname'', ''text'', ''ntext'') THEN
                            ''CAST(REPLACE(ISNULL(CAST(RTRIM('' + QUOTENAME(c.name) + '') AS VARCHAR(8000)), ''''''''), CHAR(13), '''''''') AS VARCHAR(8000)) COLLATE Latin1_General_100_BIN2''

                        WHEN ty.name IN (''binary'', ''varbinary'', ''image'') THEN
                            ''CAST('' + QUOTENAME(c.name) + '' AS VARBINARY(MAX))''

                        -- GUIDS: UPPER() Neutralizes casing differences
                        WHEN ty.name = ''uniqueidentifier'' THEN
                            ''UPPER(CAST('' + QUOTENAME(c.name) + '' AS VARCHAR(36))) COLLATE Latin1_General_100_BIN2''

                        -- DATES: Hard string truncation at 23 characters to stop Parquet floating-point tick drift
                        WHEN ty.name IN (''datetime'', ''datetime2'', ''smalldatetime'', ''date'', ''datetimeoffset'') THEN
                            ''CAST(CONVERT(VARCHAR(23), '' + QUOTENAME(c.name) + '', 121) AS VARCHAR(23)) COLLATE Latin1_General_100_BIN2''

                        WHEN ty.name = ''time'' THEN
                            ''CAST(CAST('' + QUOTENAME(c.name) + '' AS TIME(6)) AS VARCHAR(50))''

                        WHEN ty.name IN (''tinyint'', ''smallint'', ''int'', ''bigint'') THEN
                            ''CAST('' + QUOTENAME(c.name) + '' AS BIGINT)''

                        WHEN ty.name IN (''money'', ''smallmoney'') THEN
                            ''CAST('' + QUOTENAME(c.name) + '' AS DECIMAL(19,4))''

                        WHEN ty.name IN (''float'', ''real'') THEN
                            ''CONVERT(VARCHAR(50), '' + QUOTENAME(c.name) + '', 3)''

                        ELSE
                            QUOTENAME(c.name)
                    END +
                    '') AS BIGINT)''
                AS NVARCHAR(MAX)),
                '' + '' -- DECOUPLED MATH: Using addition instead of commas
            ) WITHIN GROUP (ORDER BY c.column_id)
            FROM sys.columns c
            JOIN sys.types ty ON c.user_type_id = ty.user_type_id
            WHERE c.object_id = ' + CAST(@object_id AS NVARCHAR(20)) + ';';

        EXEC sp_executesql
            @stmt = @col_query,
            @params = N'@out_cols NVARCHAR(MAX) OUTPUT',
            @out_cols = @checksum_cols OUTPUT;

        -- Note the SUM wraps the ENTIRE math equation generated above, without an inner BINARY_CHECKSUM
        SET @sql = N'SELECT @hash_out = CONVERT(VARCHAR(100), HASHBYTES(''SHA2_256'', CAST(SUM((' + @checksum_cols + ')) AS VARCHAR(MAX))), 2)
        FROM ' + QUOTENAME(@schema_name) + N'.' + QUOTENAME(@table_name) + N';';

        EXEC sp_executesql
            @stmt = @sql,
            @params = N'@hash_out VARCHAR(100) OUTPUT',
            @hash_out = @hash_value OUTPUT;

        IF (@run_mode = 'SYNAPSE')
        BEGIN
            -- FIXED: Switched to VALUES to insert exactly 1 row, bypassing the table-scan duplicates
            SET @sql = '
                INSERT INTO mgmt_xtinfra.infra_migration_validation_hashes ([SchemaName], [TableName], [SynapseTableHash], [FabricTableHash])
                VALUES (
                    ''' + @schema_name + ''',
                    ''' + @table_name + ''',
                    ' + CASE WHEN @hash_value IS NULL THEN 'NULL' ELSE '''' + @hash_value + '''' END + ',
                    NULL
                );';
        END
        ELSE
        BEGIN
            SET @sql = 'UPDATE mgmt_xtinfra.infra_migration_validation_hashes ' +
            'SET [FabricTableHash] = ' + CASE WHEN @hash_value IS NULL THEN 'NULL' ELSE '''' + @hash_value + '''' END +
            ' WHERE [SchemaName] = ' + QUOTENAME(@schema_name, '''') + ' AND [TableName] = ' + QUOTENAME(@table_name, '''') + ';'
        END

        PRINT 'Hashing table ' + CAST(@current_id AS VARCHAR(10)) + ' of ' + CAST(@total_tables AS VARCHAR(10)) + ': ' + @schema_name + '.' + @table_name;

        EXEC sp_executesql @sql;

        SET @current_id = @current_id + 1;
    END

    IF (@run_mode = 'FABRIC' AND EXISTS(
        SELECT 1
        FROM [mgmt_xtinfra].[infra_migration_validation_hashes]
        WHERE [SynapseTableHash] <> [FabricTableHash]
        OR ([SynapseTableHash] IS NULL AND [FabricTableHash] IS NOT NULL)
        OR ([SynapseTableHash] IS NOT NULL AND [FabricTableHash] IS NULL)
        ))
        THROW 50500, 'Hash validation failed. Check the table [mgmt_xtinfra].[infra_migration_validation_hashes] for details.', 5;

    DROP TABLE #TablesToHash;
END

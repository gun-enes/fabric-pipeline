CREATE PROCEDURE [mgmt_xtinfra].[infra_export_tables]
AS
BEGIN
    DECLARE @sql            NVARCHAR(MAX);
    DECLARE @sql_drop       NVARCHAR(MAX);
    DECLARE @col_query      NVARCHAR(MAX);
    DECLARE @sql_columns    NVARCHAR(MAX);
    DECLARE @schema_name    NVARCHAR(128);
    DECLARE @table_name     NVARCHAR(128);
    DECLARE @object_id      INT;
    DECLARE @current_id     INT;
    DECLARE @total_tables   INT;

    DECLARE @data_source    NVARCHAR(128) = 'mgmt-cur';
    DECLARE @file_format    NVARCHAR(128) = 'Parquet_Snappy_Format';
    SET @current_id = 1;
    IF OBJECT_ID('tempdb..#TablesToProcess') IS NOT NULL
        DROP TABLE #TablesToProcess;
    -- Get all internal tables (skipping any existing external tables)
    CREATE TABLE #TablesToProcess
    WITH (DISTRIBUTION = ROUND_ROBIN, HEAP)
    AS
    SELECT
        ROW_NUMBER() OVER(ORDER BY s.name, t.name) AS row_num,
        s.name AS schema_name,
        t.name AS table_name,
        t.object_id
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.is_external = 0;

    SELECT @total_tables = COUNT(*) FROM #TablesToProcess;
    IF @total_tables = 0
    BEGIN
        PRINT 'No internal tables found to process.';
    END
    ELSE
    BEGIN
        WHILE @current_id <= @total_tables
        BEGIN
            SELECT
                @schema_name = schema_name,
                @table_name  = table_name,
                @object_id   = object_id
            FROM #TablesToProcess
            WHERE row_num = @current_id;
            -- Generate the SELECT clause with on-the-fly casting
            SET @col_query = N'
                SELECT @out_cols = STRING_AGG(
                    CAST(
                        CASE
                            WHEN ty.name IN (''varchar'', ''char'', ''sysname'') THEN
                                ''CAST('' + QUOTENAME(c.name) + '' AS NVARCHAR('' +
                                CASE
                                    WHEN c.max_length = -1 THEN ''MAX''
                                    WHEN c.max_length > 4000 THEN ''MAX''
                                    ELSE CAST(c.max_length AS VARCHAR(10))
                                END +
                                '')) COLLATE Latin1_General_100_BIN2 AS '' + QUOTENAME(c.name)

                            WHEN ty.name IN (''nvarchar'', ''nchar'') THEN
                                ''CAST('' + QUOTENAME(c.name) + '' AS NVARCHAR('' +
                                CASE WHEN c.max_length = -1 THEN ''MAX'' ELSE CAST(c.max_length / 2 AS VARCHAR(10)) END +
                                '')) COLLATE Latin1_General_100_BIN2 AS '' + QUOTENAME(c.name)

                            WHEN ty.name IN (''text'', ''ntext'', ''xml'') THEN
                                ''CAST('' + QUOTENAME(c.name) + '' AS NVARCHAR(MAX)) COLLATE Latin1_General_100_BIN2 AS '' + QUOTENAME(c.name)

                            -- Cast uniqueidentifier to VARCHAR(36)
                            WHEN ty.name = ''uniqueidentifier'' THEN
                                ''CAST('' + QUOTENAME(c.name) + '' AS VARCHAR(36)) COLLATE Latin1_General_100_BIN2 AS '' + QUOTENAME(c.name)

                            -- Cast datetimeoffset to native DATETIME2(6) (strips the timezone)
                            WHEN ty.name = ''datetimeoffset'' THEN
                                ''CAST('' + QUOTENAME(c.name) + '' AS DATETIME2(6)) AS '' + QUOTENAME(c.name)

                            -- Cast 1-byte integer to standard INT for Parquet compatibility
                            WHEN ty.name = ''tinyint'' THEN
                                ''CAST('' + QUOTENAME(c.name) + '' AS INT) AS '' + QUOTENAME(c.name)

                            ELSE
                            QUOTENAME(c.name)
                        END AS NVARCHAR(MAX)
                    ), '', ''
                ) WITHIN GROUP (ORDER BY c.column_id)
                FROM sys.columns c
                JOIN sys.types ty ON c.user_type_id = ty.user_type_id
                WHERE c.object_id = ' + CAST(@object_id AS NVARCHAR(20)) + ';';
            EXEC sp_executesql
                @stmt = @col_query,
                @params = N'@out_cols NVARCHAR(MAX) OUTPUT',
                @out_cols = @sql_columns OUTPUT;
            -- Generate the CETAS statement
            SET @sql = 'CREATE EXTERNAL TABLE ' + QUOTENAME(@schema_name) + '.' + QUOTENAME('external_' + @table_name) +
                    ' WITH (
                            LOCATION = ''/synapse_to_fabric_migration/' + @schema_name + '_' + @table_name + '/'',
                            DATA_SOURCE = [' + @data_source + '],
                            FILE_FORMAT = [' + @file_format + ']
                    ) AS SELECT ' +
                    @sql_columns +
                    ' FROM ' + QUOTENAME(@schema_name) + '.' + QUOTENAME(@table_name) + ';';
            -- Generate the cleanup statement
            SET @sql_drop = 'DROP EXTERNAL TABLE ' + QUOTENAME(@schema_name) + '.' + QUOTENAME('external_' + @table_name) + ';';
            PRINT 'Processing table ' + CAST(@current_id AS VARCHAR(10)) + ' of ' + CAST(@total_tables AS VARCHAR(10)) + ': ' + @schema_name + '.' + @table_name;

            EXEC sp_executesql @sql;       -- Executes the export to the blob storage
            EXEC sp_executesql @sql_drop;  -- Cleans up the external table metadata from Synapse
            SET @current_id = @current_id + 1;
        END
    END
    DROP TABLE #TablesToProcess;
END

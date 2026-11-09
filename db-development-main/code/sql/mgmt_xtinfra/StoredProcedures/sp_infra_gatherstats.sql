/*
Description:
This stored procedure is used to create stats gather schedule for DB/Schema.

Author:
jyothish.b@allianz.com
*/

CREATE PROC [mgmt_xtinfra].[sp_infra_gatherstats]
    @stats_type [NVARCHAR](6),
    @stats_pct [INT],
    @schema_name [NVARCHAR](43)
AS
BEGIN
    DECLARE @stats_statement_counter INT = 1;
    DECLARE @stats_table_counter INT;
    DECLARE @stats_statement NVARCHAR(4000) = N'';
    DECLARE @session_id_counter INT = (
        SELECT ISNULL(MAX(session_id), 0)
        FROM mgmt_xtinfra.infra_stats_master
    ) + 1;
    DECLARE @exec_id_counter INT = (
        SELECT ISNULL(MAX(execid), 0) AS maxexecid
        FROM mgmt_xtinfra.infra_stats_master
    ) + 1;
    DECLARE @db_name NVARCHAR(100);
    DECLARE @current_user NVARCHAR(100);
    DECLARE @now DATETIME = SYSDATETIME();
    DECLARE @job_desc NVARCHAR(MAX) = 'Infra stats master operation';
    DECLARE @scriptversionid VARCHAR(1000) = (
        SELECT scriptversionid
        FROM mgmt_xtinfra.infra_script_master
        WHERE script_status = 'current'
    );

    SET @db_name = DB_NAME();
    SET @current_user = CURRENT_USER;

    IF (@stats_type IS NULL)
    BEGIN
       RAISERROR('Invalid value for stats_type parameter.Expected input values DB or SCHEMA', 16, 1);
    END

    IF (@stats_type = 'SCHEMA' AND @schema_name IS NULL)
    BEGIN
        RAISERROR('Invalid value for schema_name parameter. Schema_name cannot be null', 16, 1);
    END

    IF @stats_type NOT IN ('DB', 'SCHEMA')
    BEGIN
        RAISERROR('Invalid value for stats_type parameter.Expected input values DB or SCHEMA', 16, 1);
    END

    IF (@stats_pct NOT BETWEEN 1 AND 100)
    BEGIN
        RAISERROR('Kindly provide a valid  stats_pct - between 1 to 100', 16, 1);
    END
    -- Skip Table list discrepancy in column order between constraint column and column store index columns
    IF OBJECT_ID('mgmt_xtinfra.infra_stats_skip_details') IS NOT NULL
    BEGIN
        TRUNCATE TABLE [mgmt_xtinfra].[infra_stats_skip_details];
    END;

    WITH ClusteredColumnstoreIndexes AS
        (SELECT
            t.[object_id] AS TableObjectId,
            s.[name] AS SchemaName,
            t.[name] AS TableName,
            i.[index_id] AS IndexId,
            i.[name] AS IndexName
        FROM
            sys.[tables] t
        JOIN
            sys.[schemas] s ON t.[schema_id] = s.[schema_id]
        JOIN
            sys.[indexes] i ON t.[object_id] = i.[object_id]
        WHERE
            i.[type] = 5 -- 5 indicates CLUSTERED COLUMNSTORE INDEX
    ),
    ConstraintColumns AS (
        SELECT
            kc.[parent_object_id] AS TableObjectId,
            kc.[name] AS ConstraintName,
            c.[name] AS ColumnName,
            ic.[key_ordinal] AS ColumnOrder
        FROM
            sys.[key_constraints] kc
        JOIN
            sys.[index_columns] ic ON kc.[parent_object_id] = ic.[object_id] AND kc.[unique_index_id] = ic.[index_id]
        JOIN
            sys.[columns] c ON ic.[object_id] = c.[object_id] AND ic.[column_id] = c.[column_id]
        WHERE
            kc.[type] = 'PK'
    ),
    ColumnstoreIndexColumns AS (
        SELECT
            ic.[object_id] AS TableObjectId,
            c.[name] AS ColumnName,
            ic.[index_column_id] AS ColumnOrder
        FROM
            sys.[index_columns] ic
        JOIN
            sys.[columns] c ON ic.[object_id] = c.[object_id] AND ic.[column_id] = c.[column_id]
        JOIN
            [ClusteredColumnstoreIndexes] ci ON ic.[object_id] = ci.[TableObjectId] AND ic.[index_id] = ci.[IndexId]
    )
    INSERT INTO [mgmt_xtinfra].[infra_stats_skip_details]
    (SchemaName, TableName, ConstraintName, ConstraintColumnName, ConstraintColumnOrder, ColumnstoreIndexColumnName, ColumnstoreIndexColumnOrder)
    SELECT
        cci.[SchemaName],
        cci.[TableName],
        cc.[ConstraintName],
        cc.[ColumnName] AS ConstraintColumnName,
        cc.[ColumnOrder] AS ConstraintColumnOrder,
        ci.[ColumnName] AS ColumnstoreIndexColumnName,
        ci.[ColumnOrder] AS ColumnstoreIndexColumnOrder
        FROM
        [ConstraintColumns] cc
        JOIN
        [ColumnstoreIndexColumns] ci ON cc.[TableObjectId] = ci.[TableObjectId] AND cc.[ColumnName] = ci.[ColumnName]
        JOIN
        [ClusteredColumnstoreIndexes] cci ON cc.[TableObjectId] = cci.[TableObjectId]
        WHERE
        cc.[ColumnOrder] <> ci.[ColumnOrder];


    --- Stats collection block start here
    --- create new stats for FULL DB
    IF @stats_type IN ('DB')
    BEGIN
        SET @job_desc = 'FULL DB STATS_CREATION';
        INSERT INTO mgmt_xtinfra.infra_stats_master (
            [execid],
            [session_id],
            [scriptversionid],
            [dbname],
            [job_desc],
            [status],
            [job_start_time],
            [job_end_time],
            [exec_user]
        )
        SELECT
            @exec_id_counter,
            @session_id_counter,
            @scriptversionid,
            @db_name,
            @job_desc,
            'started',
            @now,
            NULL,
            @current_user;

        IF OBJECT_ID('tempdb..#db_stats_ddl') IS NOT NULL
        BEGIN
            DROP TABLE #db_stats_ddl;
        END

        CREATE TABLE #db_stats_ddl WITH (
            DISTRIBUTION = HASH([seq_nmbr]),
            LOCATION = USER_DB
        ) AS
        WITH T AS (
            SELECT
                t.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [table_name],
                s.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [table_schema_name],
                c.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [column_name],
                c.[column_id] AS [column_id],
                t.[object_id] AS [object_id],
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [seq_nmbr]
            FROM
                sys.[tables] t
            JOIN sys.[schemas] s ON t.[schema_id] = s.[schema_id]
            JOIN sys.[columns] c ON t.[object_id] = c.[object_id]
            LEFT JOIN sys.[stats_columns] l ON l.[object_id] = c.[object_id]
                AND l.[column_id] = c.[column_id]
                AND l.[stats_column_id] = 1
            LEFT JOIN sys.[external_tables] e ON e.[object_id] = t.[object_id]
            LEFT JOIN [mgmt_xtinfra].[infra_stats_skip_details] sd ON sd.[SchemaName] = s.[NAME] AND sd.[TableName] = t.[name]
            WHERE
                l.[object_id] IS NULL
                AND e.[object_id] IS NULL -- not an external table
        )
        SELECT
            [table_schema_name],
            [table_name],
            [column_name],
            [column_id],
            [object_id],
            [seq_nmbr],
            CAST('CREATE STATISTICS ' + QUOTENAME('stat_' + table_schema_name + '_' + table_name + '_' + column_name) + ' ON ' + QUOTENAME(table_schema_name) + '.' + QUOTENAME(table_name) + '(' + QUOTENAME(column_name) + ') WITH SAMPLE ' + CAST(@stats_pct AS NVARCHAR(3)) + ' PERCENT' AS VARCHAR(8000)) AS create_stat_ddl
        FROM
            T;

        SET @stats_statement_counter = 1;
        SET @stats_table_counter = (
            SELECT COUNT(*)
            FROM #db_stats_ddl
        );
        SET @stats_statement = N'';

        WHILE @stats_statement_counter <= @stats_table_counter
        BEGIN
            SET @stats_statement = (
                SELECT create_stat_ddl
                FROM #db_stats_ddl
                WHERE seq_nmbr = @stats_statement_counter
            );

            PRINT @stats_statement;
            EXEC sp_executesql @stats_statement;
            SET @stats_statement_counter += 1;
        END;

        DROP TABLE #db_stats_ddl;

        SET @now = SYSDATETIME();

        UPDATE mgmt_xtinfra.infra_stats_master
        SET
            status = 'completed',
            job_end_time = @now
        WHERE
            execid = @exec_id_counter
            AND session_id = @session_id_counter;

        IF OBJECT_ID('mgmt_xtinfra.infra_stats_update_details') IS NOT NULL
        BEGIN
            DROP TABLE mgmt_xtinfra.infra_stats_update_details;
        END

        CREATE TABLE mgmt_xtinfra.infra_stats_update_details WITH (
            DISTRIBUTION = REPLICATE,
            CLUSTERED COLUMNSTORE INDEX
        ) AS
        WITH cmp_summary AS (
            SELECT
                tm.[object_id],
                SUM(ps.row_count) cmp_row_count,
                CASE WHEN SUM(ps.row_count) = 0 THEN 100 ELSE SQRT(SUM(ps.row_count)) * 1000 / SUM(ps.row_count) * 100 END AS stats_sample_rate,
                CONVERT(BIGINT, SQRT(1000 * SUM(ps.row_count))) AS dynamic_threshold_rows
            FROM
                sys.[dm_pdw_nodes_db_partition_stats] ps
            INNER JOIN sys.[pdw_nodes_tables] nt ON nt.[object_id] = ps.[object_id] AND ps.[distribution_id] = nt.[distribution_id]
            INNER JOIN sys.[pdw_table_mappings] tm ON tm.[physical_name] = nt.[name]
            WHERE ps.[index_id] < 2
            GROUP BY tm.[object_id]
        ),
        ctl_summary AS (
            SELECT
                t.[object_id],
                s.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS schema_name,
                t.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS table_name,
                i.[type_desc] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS table_type,
                dp.[distribution_policy_desc] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS distribution_type,
                SUM(p.rows) ctl_row_count
            FROM
                sys.[schemas] s
            INNER JOIN sys.[tables] t ON t.[schema_id] = s.[schema_id]
            INNER JOIN sys.[pdw_table_distribution_properties] dp ON dp.[object_id] = t.[object_id]
            INNER JOIN sys.[indexes] i ON i.[object_id] = t.[object_id] AND i.[index_id] < 2
            INNER JOIN sys.[partitions] p ON p.[object_id] = t.[object_id] AND p.[index_id] = i.[index_id]
            GROUP BY t.[object_id], s.[name], t.[name], i.[type_desc], dp.[distribution_policy_desc]
        ),
        [all_results] AS (
            SELECT
                ctl.[object_id],
                ctl.[schema_name],
                ctl.[table_name],
                ctl.[table_type],
                ctl.[distribution_type],
                ctl.[ctl_row_count] AS stats_row_count,
                cmp.[cmp_row_count] AS actual_row_count,
                CONVERT(DECIMAL(10, 2), (ABS(ctl.ctl_row_count - cmp.cmp_row_count) * 100.0 / NULLIF(cmp.cmp_row_count, 0))) stats_difference_percent,
                CONVERT(INT, CASE WHEN cmp.stats_sample_rate < 1 THEN 1 WHEN cmp.stats_sample_rate > 100 THEN 100 ELSE cmp.stats_sample_rate END) AS stats_sample_rate,
                cmp.[dynamic_threshold_rows]
            FROM [ctl_summary] ctl
            INNER JOIN [cmp_summary] cmp ON ctl.[object_id] = cmp.[object_id]
        )
        SELECT
            [object_id],
            [schema_name],
            [table_name],
            [table_type],
            [distribution_type],
            [stats_row_count],
            [actual_row_count],
            [stats_difference_percent],
            [dynamic_threshold_rows],
            [stats_sample_rate],
            CASE WHEN stats_difference_percent >= 30 OR ABS([actual_row_count] - [stats_row_count]) > dynamic_threshold_rows THEN 1 ELSE 0 END AS recommend_update,
            'UPDATE STATISTICS ' + QUOTENAME([schema_name]) + '.' + QUOTENAME([table_name]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS update_stats_ddl
        FROM [all_results];
    END -- FULL DB Statistics collection end here
    ELSE IF @stats_type IN ('SCHEMA')
    --- create new stats for the requested SCHEMA
    BEGIN
        SET @job_desc = 'SCHEMA STATS_CREATION for the tables';
        INSERT INTO mgmt_xtinfra.infra_stats_master (
            [execid],
            [session_id],
            [scriptversionid],
            [dbname],
            [job_desc],
            [status],
            [job_start_time],
            [job_end_time],
            [exec_user]
        )
        SELECT
            @exec_id_counter,
            @session_id_counter,
            @scriptversionid,
            @db_name,
            @job_desc,
            'started',
            @now,
            NULL,
            @current_user;

        IF OBJECT_ID('tempdb..#schema_stats_ddl') IS NOT NULL
        BEGIN
            DROP TABLE #schema_stats_ddl;
        END

        CREATE TABLE #schema_stats_ddl WITH (
            DISTRIBUTION = HASH([seq_nmbr]),
            LOCATION = USER_DB
        ) AS
        WITH T AS (
            SELECT
                t.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [table_name],
                s.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [table_schema_name],
                c.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [column_name],
                c.[column_id] AS [column_id],
                t.[object_id] AS [object_id],
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [seq_nmbr]
            FROM
                sys.[tables] t
            JOIN sys.[schemas] s ON t.[schema_id] = s.[schema_id]
            JOIN sys.[columns] c ON t.[object_id] = c.[object_id]
            LEFT JOIN sys.[stats_columns] l ON l.[object_id] = c.[object_id]
                AND l.[column_id] = c.[column_id]
                AND l.[stats_column_id] = 1
            LEFT JOIN sys.[external_tables] e ON e.[object_id] = t.[object_id]
            LEFT JOIN [mgmt_xtinfra].[infra_stats_skip_details] sd ON sd.SchemaName = s.NAME AND sd.TableName = t.name
            WHERE
                l.[object_id] IS NULL
                AND e.[object_id] IS NULL
                AND s.[name] = @schema_name -- not an external table
        )
        SELECT
            [table_schema_name],
            [table_name],
            [column_name],
            [column_id],
            [object_id],
            [seq_nmbr],
            CAST('CREATE STATISTICS ' + QUOTENAME('stat_' + table_schema_name + '_' + table_name + '_' + column_name) + ' ON ' + QUOTENAME(table_schema_name) + '.' + QUOTENAME(table_name) + '(' + QUOTENAME(column_name) + ') WITH SAMPLE ' + CAST(@stats_pct AS NVARCHAR(3)) + ' PERCENT' AS VARCHAR(8000)) AS create_stat_ddl
        FROM T;

        SET @stats_statement_counter = 1;
        SET @stats_table_counter  = (
            SELECT COUNT(*)
            FROM #schema_stats_ddl
        );
        SET @stats_statement = N'';

        WHILE @stats_statement_counter <= @stats_table_counter
        BEGIN
            SET @stats_statement = (
                SELECT create_stat_ddl
                FROM #schema_stats_ddl
                WHERE seq_nmbr = @stats_statement_counter
            );

            PRINT @stats_statement;
            EXEC sp_executesql @stats_statement;
            SET @stats_statement_counter += 1;
        END;

        DROP TABLE #schema_stats_ddl;

        SET @now = SYSDATETIME();

        UPDATE mgmt_xtinfra.infra_stats_master
        SET
            status = 'completed',
            job_end_time = @now
        WHERE
            execid = @exec_id_counter
            AND session_id = @session_id_counter;

        IF OBJECT_ID('mgmt_xtinfra.infra_stats_update_details') IS NOT NULL
        BEGIN
            DROP TABLE mgmt_xtinfra.infra_stats_update_details;
        END

        CREATE TABLE mgmt_xtinfra.infra_stats_update_details WITH (
            DISTRIBUTION = REPLICATE,
            CLUSTERED COLUMNSTORE INDEX
        ) AS
        WITH cmp_summary AS (
            SELECT
                tm.[object_id],
                SUM(ps.row_count) cmp_row_count,
                CASE WHEN SUM(ps.row_count) = 0 THEN 100 ELSE SQRT(SUM(ps.row_count)) * 1000 / SUM(ps.row_count) * 100 END AS stats_sample_rate,
                CONVERT(BIGINT, SQRT(1000 * SUM(ps.row_count))) AS dynamic_threshold_rows
            FROM
                sys.[dm_pdw_nodes_db_partition_stats] ps
            INNER JOIN sys.[pdw_nodes_tables] nt ON nt.[object_id] = ps.[object_id] AND ps.[distribution_id] = nt.[distribution_id]
            INNER JOIN sys.[pdw_table_mappings] tm ON tm.[physical_name] = nt.[name]
            WHERE ps.[index_id] < 2
            GROUP BY tm.[object_id]
        ),
        ctl_summary AS (
            SELECT
                t.[object_id],
                s.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [schema_name],
                t.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS table_name,
                i.[type_desc] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS table_type,
                dp.[distribution_policy_desc] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS distribution_type,
                SUM(p.rows) ctl_row_count
            FROM
                sys.[schemas] s
            INNER JOIN sys.[tables] t ON t.[schema_id] = s.[schema_id]
            INNER JOIN sys.[pdw_table_distribution_properties] dp ON dp.[object_id] = t.[object_id]
            INNER JOIN sys.[indexes] i ON i.[object_id] = t.[object_id] AND i.[index_id] < 2
            INNER JOIN sys.[partitions] p ON p.[object_id] = t.[object_id] AND p.[index_id] = i.[index_id]
            GROUP BY t.[object_id], s.[name], t.[name], i.[type_desc], dp.[distribution_policy_desc]
        ),
        [all_results] AS (
            SELECT
                ctl.[object_id],
                ctl.[schema_name],
                ctl.[table_name],
                ctl.[table_type],
                ctl.[distribution_type],
                ctl.[ctl_row_count] AS stats_row_count,
                cmp.[cmp_row_count] AS actual_row_count,
                CONVERT(DECIMAL(10, 2), (ABS(ctl.ctl_row_count - cmp.cmp_row_count) * 100.0 / NULLIF(cmp.cmp_row_count, 0))) stats_difference_percent,
                CONVERT(INT, CASE WHEN cmp.stats_sample_rate < 1 THEN 1 WHEN cmp.stats_sample_rate > 100 THEN 100 ELSE cmp.stats_sample_rate END) AS stats_sample_rate,
                cmp.[dynamic_threshold_rows]
            FROM [ctl_summary] ctl
            INNER JOIN [cmp_summary] cmp ON ctl.[object_id] = cmp.[object_id]
        )
        SELECT
            [object_id],
            [schema_name],
            [table_name],
            [table_type],
            [distribution_type],
            [stats_row_count],
            [actual_row_count],
            [stats_difference_percent],
            [dynamic_threshold_rows],
            [stats_sample_rate],
            CASE WHEN stats_difference_percent >= 30 OR ABS([actual_row_count] - [stats_row_count]) > dynamic_threshold_rows THEN 1 ELSE 0 END AS recommend_update,
            'UPDATE STATISTICS ' + QUOTENAME([schema_name]) + '.' + QUOTENAME([table_name]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS update_stats_ddl
        FROM [all_results]
        WHERE [schema_name] = @schema_name;
    END -- SCHEMA Statistics collection end here

    ----------------- Update stat job starting here
    SET @job_desc = 'STATS_UPDATION for the tables having 30% stale percentage or above';

    SET @exec_id_counter = (
        SELECT ISNULL(MAX(execid), 0) AS maxexecid
        FROM mgmt_xtinfra.infra_stats_master
    ) + 1;

    SET @now = SYSDATETIME();

    INSERT INTO mgmt_xtinfra.infra_stats_master (
        [execid],
        [session_id],
        [scriptversionid],
        [dbname],
        [job_desc],
        [status],
        [job_start_time],
        [job_end_time],
        [exec_user]
    )
    SELECT
        @exec_id_counter,
        @session_id_counter,
        @scriptversionid,
        @db_name,
        @job_desc,
        'started',
        @now,
        NULL,
        @current_user;

    ----- Updating the stats and skipping the problematic tables with column order issue
    IF OBJECT_ID('tempdb..#update_stats_ddl') IS NOT NULL
    BEGIN
        DROP TABLE #update_stats_ddl;
    END

    CREATE TABLE #update_stats_ddl WITH (
        DISTRIBUTION = HASH([update_stats_ddl]),
        LOCATION = USER_DB
    ) AS
    WITH STATS_SUBQ AS (
        SELECT
            [update_stats_ddl],
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [seq_nmbr]
        FROM
            [mgmt_xtinfra].[infra_stats_update_details] t
        LEFT JOIN [mgmt_xtinfra].[infra_stats_skip_details] sd ON sd.[SchemaName] = t.[schema_name] AND sd.[TableName] = t.[table_name]
        WHERE t.[recommend_update] = 1
        AND t.[table_name] NOT IN (
            SELECT [NAME]
            FROM sys.[external_tables]
        )
    )
    SELECT * FROM [STATS_SUBQ];

    SET @stats_statement_counter = 1;
    SET @stats_table_counter = (
        SELECT COUNT(*)
        FROM #update_stats_ddl
    );

    SET @stats_statement  = N'';

    WHILE @stats_statement_counter <= @stats_table_counter
    BEGIN
        SET @stats_statement = (
            SELECT update_stats_ddl
            FROM #update_stats_ddl
            WHERE seq_nmbr = @stats_statement_counter
        );

        PRINT @stats_statement;
        EXEC sp_executesql @stats_statement;
        SET @stats_statement_counter += 1;
    END;

    DROP TABLE #update_stats_ddl;

    SET @now = SYSDATETIME();

    UPDATE mgmt_xtinfra.infra_stats_master
    SET
        status = 'completed',
        job_end_time = @now
    WHERE
        execid = @exec_id_counter
        AND session_id = @session_id_counter;

    --- Update stat job ending here
    DELETE FROM mgmt_xtinfra.infra_stats_master
    WHERE DATEDIFF(day, job_start_time, @now) > 60;
END
GO

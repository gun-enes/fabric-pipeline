/*
    Description:
        Restores a single table from its corresponding CETAS external staging table.
        This procedure reverses the datatype transformations applied during backup:
            - 0x00 placeholders are converted back to empty strings ('') for character types.
            - VARBINARY(MAX) values are cast back to original text types to restore UTF-8 correctly
              (external tables do not preserve UTF-8 column-level encoding).
            - uniqueidentifier values are converted back from their CHAR(255) representation.
        Identity columns are handled via IDENTITY_INSERT when required.

    Author:
        extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_restore_single_table]
    @table_schema VARCHAR(4000),
    @table_name VARCHAR(4000),
    @filename VARCHAR(4000)

AS
BEGIN
    DECLARE
        @staging_table VARCHAR(4000),
        @restore_full VARCHAR(4000),
        @sql NVARCHAR(MAX),
        @error_count INT = 0,
        @proc_name NVARCHAR(128) = 'sp_infra_restore_single_table',
        @log_detail_group UNIQUEIDENTIFIER = NEWID(),
        @has_identity BIT,
        @backup_eds_name NVARCHAR(128),
        @cmd NVARCHAR(MAX);

    SET @staging_table = @table_schema + '.exttable_' + @table_name;
    SET @restore_full = @table_schema + '.' + @table_name;
    PRINT ('Restore operation initialized for table ' + @restore_full);

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'table_name', @restore_full;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'restore_external_table_name', @staging_table;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'restore_filename', @filename;

        IF OBJECT_ID(@staging_table, 'ET') IS NULL
            BEGIN
                -- Generate dynamic SELECT with CETAS-safe column transformations
                -- (handles empty strings, UTF-8 preservation, uniqueidentifier conversion)
                EXEC [mgmt_xtinfra].[sp_collate_columns_for_CETAS] @table_schema, @table_name, @cmd OUTPUT;

                -- Set backup external data source from global config
                SELECT @backup_eds_name = [value]
                FROM [mgmt_xtinfra].[infra_global_config]
                WHERE [key] = 'backup_external_data_source';

                -- Create CETAS external table for restore
                SET @sql = '
                    CREATE EXTERNAL TABLE ' + @staging_table + '
                    WITH (
                        LOCATION = ''backup/' + ISNULL(@filename, '') + ''',
                        DATA_SOURCE = ' + QUOTENAME(@backup_eds_name) + ',
                        FILE_FORMAT = [external_fileformat_comma_delimited_quoted_text_row2]
                    )
                    AS ' + @cmd + ';';

                EXEC [sp_executesql] @sql;
            END

        SET @sql = 'TRUNCATE TABLE ' + @restore_full;
        EXEC [sp_executesql] @sql;

        IF OBJECT_ID('tempdb..#colinfo') IS NOT NULL
            DROP TABLE #colinfo;

        SELECT
            [column].[name] AS [colname],
            [type].[name] AS [typename],
            [column].[max_length]
        INTO #colinfo
        FROM [sys].[columns] AS [column]
        INNER JOIN [sys].[types] AS [type] ON [column].[user_type_id] = [type].[user_type_id]
        WHERE [column].[object_id] = OBJECT_ID(QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name));

        SET @has_identity = (
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM [sys].[columns] AS [column]
                    WHERE
                        [column].[object_id] = OBJECT_ID(QUOTENAME(@table_schema) + '.' + QUOTENAME(@table_name))
                        AND [column].[is_identity] = 1
                ) THEN 1
                ELSE 0
            END
        );

        DECLARE @converted_cols NVARCHAR(MAX) = '';

        SELECT
            @converted_cols = STRING_AGG(CAST(
                CASE
                    WHEN [typename] IN ('char', 'varchar', 'nvarchar', 'nchar', 'sysname')
                        /*
                            RESTORE-side mapping for character datatypes:
                                - 0x00 (placeholder for empty string during CETAS export) converts back to ''.
                                - Other values were stored as VARBINARY(MAX), so cast them back to their
                                original text types to restore UTF-8 correctly, since external tables do
                                not preserve UTF-8 column-level encoding.

                                Length reconstruction rules:
                                    - max_length = -1  → use (MAX) for varchar/nvarchar.
                                    - nvarchar/nchar store length in bytes, so divide by 2 to get character length.
                                    - sysname always maps back without length specification.
                                    - Other char/varchar types restore their exact original length.
                        */
                        THEN
                            'CASE
                        WHEN ' + QUOTENAME([colname]) + ' = 0x00
                            THEN ''''
                        ELSE
                            CAST(' + QUOTENAME([colname]) + ' AS ' + [typename]
                            + CASE
                                WHEN [max_length] = -1
                                    THEN '(MAX)'
                                WHEN [typename] IN ('nvarchar', 'nchar')
                                    THEN '(' + CAST([max_length] / 2 AS VARCHAR) + ')'
                                WHEN [typename] = 'sysname'
                                    THEN ''
                                ELSE '(' + CAST([max_length] AS VARCHAR) + ')'
                            END + ')
                        END AS ' + QUOTENAME([colname])
                    WHEN [typename] = 'uniqueidentifier'
                        /*
                            RESTORE-side mapping for uniqueidentifier:
                                - GUID values were exported as CHAR(255) with a fixed collation in CETAS.
                                - Convert them back to uniqueidentifier to restore the original datatype.
                        */
                        THEN 'CONVERT(uniqueidentifier, ' + QUOTENAME([colname]) + ') AS ' + QUOTENAME([colname])
                    ELSE
                        QUOTENAME([colname])
                END AS NVARCHAR(MAX)
            ),
            ', ')
        FROM #colinfo;

        DECLARE @cols NVARCHAR(MAX) = '';
        SELECT @cols = STRING_AGG(CAST(QUOTENAME([colname]) AS NVARCHAR(MAX)), ',') FROM #colinfo;

        SET @sql = '';

        IF @has_identity = 1
            SET @sql = @sql + ' SET IDENTITY_INSERT ' + @restore_full + ' ON '
        SET
            @sql = @sql
            + 'INSERT INTO ' + @restore_full + ' (' + @cols + ')
        SELECT ' + @converted_cols + '
        FROM ' + @staging_table
        IF @has_identity = 1
            SET @sql = @sql + ' SET IDENTITY_INSERT ' + @restore_full + ' OFF '

        EXEC (@sql);

        UPDATE [mgmt_xtinfra].[infra_dr_backup_master]
        SET [status] = 'RESTORE-SUCCESS'
        WHERE
            [table_schema] = @table_schema
            AND [table_name] = @table_name;

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'success';
    END TRY
    BEGIN CATCH
        DECLARE
            @error_message NVARCHAR(4000) = 'Restore failed for ' + @restore_full
            + ' — ' + ERROR_MESSAGE();
        DECLARE @error_severity INT = ERROR_SEVERITY();
        DECLARE @error_state INT = ERROR_STATE();

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_message', @error_message;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_severity', @error_severity;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_state', @error_state;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'failure';

        UPDATE [mgmt_xtinfra].[infra_dr_backup_master]
        SET [status] = 'RESTORE-FAILED'
        WHERE
            [table_schema] = @table_schema
            AND [table_name] = @table_name;

        RAISERROR (@error_message, 16, 1);
    END CATCH
END;

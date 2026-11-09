/*
    Description: Backup operation with single table

    Author:
    extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_backup_single_table]
    @table_schema VARCHAR(4000),
    @table_name VARCHAR(4000),
    @filename VARCHAR(4000)
AS
BEGIN
    DECLARE
        @staging_table VARCHAR(4000),
        @backup_full VARCHAR(4000),
        @sql NVARCHAR(MAX),
        @error_count INT = 0,
        @proc_name NVARCHAR(128) = 'sp_infra_backup_single_table',
        @log_detail_group UNIQUEIDENTIFIER = NEWID(),
        @backup_eds_name NVARCHAR(128),
        @cmd NVARCHAR(MAX);

    SET @staging_table = @table_schema + '.exttable_' + @table_name;
    SET @backup_full = @table_schema + '.' + @table_name;
    PRINT ('Backup operation initialized for table ' + @backup_full);

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'table_name', @backup_full;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'backup_external_table_name', @staging_table;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'backup_filename', @filename;

        IF OBJECT_ID(@staging_table, 'ET') IS NOT NULL
            BEGIN
                EXEC ('DROP EXTERNAL TABLE ' + @staging_table + ';');
            END

        -- Generate dynamic SELECT with CETAS-safe column transformations
        -- (handles empty strings, UTF-8 preservation, uniqueidentifier conversion)
        EXEC [mgmt_xtinfra].[sp_collate_columns_for_CETAS] @table_schema, @table_name, @cmd OUTPUT;

        -- Set backup external data source from global config
        SELECT @backup_eds_name = [value]
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = 'backup_external_data_source';

        -- Create CETAS external table for backup
        SET @sql = '
            CREATE EXTERNAL TABLE ' + @staging_table + '
            WITH (
                LOCATION = ''backup/' + @filename + ''',
                DATA_SOURCE = ' + QUOTENAME(@backup_eds_name) + ',
                FILE_FORMAT = [external_fileformat_comma_delimited_quoted_text_row2]
            )
            AS ' + @cmd + ';';

        EXEC [sp_executesql] @sql;

        UPDATE [mgmt_xtinfra].[infra_dr_backup_master]
        SET [status] = 'BACKUP-SUCCESS'
        WHERE
            [table_schema] = @table_schema
            AND [table_name] = @table_name;

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'success';
    END TRY
    BEGIN CATCH
        DECLARE
            @error_message NVARCHAR(4000) = 'Backup failed for ' + @backup_full
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
        SET [status] = 'BACKUP-FAILED'
        WHERE
            [table_schema] = @table_schema
            AND [table_name] = @table_name;

        RAISERROR (@error_message, 16, 1);
    END CATCH
END;

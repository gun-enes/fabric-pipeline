/*
    Description: Restore all tables based on entries in
        infra_dr_backup_master.

    Author:
    extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_restore_all_tables]
AS
BEGIN
    DECLARE
        @row_id INT = 1,
        @table_row_count INT,
        @table_schema VARCHAR(4000),
        @table_name VARCHAR(4000),
        @filename VARCHAR(4000),
        @error_count INT = 0,
        @failures NVARCHAR(MAX) = N'',
        @proc_name NVARCHAR(128) = 'sp_infra_restore_all_tables',
        @restore_table_error NVARCHAR(4000),
        @log_detail_group UNIQUEIDENTIFIER = NEWID();

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        SELECT
            [table_schema],
            [table_name],
            [filename],
            ROW_NUMBER() OVER (ORDER BY [table_schema], [table_name]) AS [rn]
        INTO #BackupTableList
        FROM [mgmt_xtinfra].[infra_dr_backup_master]
        WHERE
            [status] <> 'RESTORE-SUCCESS'
            AND [table_name] <> 'infra_dr_backup_master';

        SELECT @table_row_count = COUNT(*) FROM #BackupTableList;

        WHILE @row_id <= @table_row_count
            BEGIN
                BEGIN TRY
                    SELECT
                        @table_schema = [table_schema],
                        @table_name = [table_name],
                        @filename = [filename]
                    FROM #BackupTableList
                    WHERE [rn] = @row_id;

                    EXEC [mgmt_xtinfra].[sp_infra_restore_single_table]
                        @table_schema,
                        @table_name,
                        @filename;
                END TRY
                BEGIN CATCH
                    SET @error_count = @error_count + 1;
                    SET @restore_table_error = QUOTENAME(@table_schema + '.' + @table_name) + ' => ' + ERROR_MESSAGE();
                    SET @failures = @failures + @restore_table_error + CHAR(13);
                END CATCH;
                SET @row_id = @row_id + 1;
            END;

        IF @error_count = 0
            BEGIN
                EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
                    @log_detail_group, @proc_name, 'success';
            END
        ELSE
            BEGIN
                EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
                    @log_detail_group, 'total_failures', @error_count;

                DECLARE
                    @throwMessage NVARCHAR(MAX) = 'Restore failures:' + CHAR(13) + @failures + CHAR(13) + 'Total failures count:' + CONVERT(CHAR(255), @error_count);

                THROW 50000, @throwMessage, 1;
            END

    END TRY
    BEGIN CATCH
        DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
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

        THROW 50000, @error_message, 1;
    END CATCH
END

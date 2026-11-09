/*
    Description: Drops all external tables used for DR backup/restore based on entries in
        infra_dr_backup_master.

    Author:
    extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_drop_dr_backup_exttables]
    @OPS_TYPE [VARCHAR](16)
AS
BEGIN
    DECLARE
        @row_id INT = 1,
        @table_row_count INT,
        @table_schema VARCHAR(4000),
        @table_name VARCHAR(4000),
        @tab_rename VARCHAR(4000),
        @ext_table VARCHAR(4000),
        @sql NVARCHAR(MAX),
        @failures NVARCHAR(MAX) = N'',
        @proc_name NVARCHAR(128) = 'sp_infra_drop_dr_backup_exttables',
        @log_detail_group UNIQUEIDENTIFIER = NEWID(),
        @error_count INT = 0;
    BEGIN TRY
     EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
     SELECT
        [table_schema],
        [table_name],
        [tab_rename],
        ROW_NUMBER() OVER (ORDER BY [table_schema], [table_name]) AS [rn]
     INTO #DropExtTableList
     FROM [mgmt_xtinfra].[infra_dr_backup_master];

    SELECT @table_row_count = COUNT(*) FROM #DropExtTableList;

    WHILE @row_id <= @table_row_count
        BEGIN
            BEGIN TRY
                SELECT
                    @table_schema = [table_schema],
                    @table_name = [table_name],
                    @tab_rename   = [tab_rename]
                FROM #DropExtTableList
                WHERE [rn] = @row_id;

                IF @OPS_TYPE = 'PITR'
                    SET @ext_table = @table_schema + '.exttable_' + @tab_rename;
                ELSE
                    SET @ext_table = @table_schema + '.exttable_' + @table_name;

                EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
                    @log_detail_group, 'external_table', @ext_table;

                IF OBJECT_ID(@ext_table, 'ET') IS NOT NULL
                    BEGIN
                        SET @sql = 'DROP EXTERNAL TABLE ' + @ext_table + ';';
                        EXEC (@sql);
                    END
            END TRY

            BEGIN CATCH
                SET @error_count += 1;

                DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
                DECLARE @clean_failure_line NVARCHAR(4000) = QUOTENAME(@ext_table) + ' => ' + @err;

                SET @failures = @failures + @clean_failure_line + CHAR(13);

                EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
                    @log_detail_group, 'drop_failure', @clean_failure_line;
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
                @throwMessage NVARCHAR(MAX)
                = 'Drop external tables failures:' + CHAR(13)
                + @failures + CHAR(13)
                + 'Total failures count:' + CONVERT(VARCHAR(255), @error_count);
             EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error', @throwMessage;
            THROW 50000, @throwMessage, 1;
        END
    END TRY
    BEGIN CATCH
        DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @error_severity INT = ERROR_SEVERITY();
        DECLARE @error_state INT = ERROR_STATE();
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_message', @error_message
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_severity', @error_severity
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_state', @error_state
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'failure';
        --- then throw again to forward error
        THROW;
    END CATCH
END;

/*
Description:
This stored procedure is used to kill the session for self service.

Author:
jyothish.b@allianz.com
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_killsession_run_to_version] @mode [nvarchar](32),@start_version [int],@end_version [int],@session_id [nvarchar](128) AS
BEGIN
    --- define required variables
    DECLARE @proc_name nvarchar(128) = 'sp_infra_killsession_run_to_version';
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(512);

    BEGIN TRY
    --- assign logging details already here
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'start_version', @start_version;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'end_version', @end_version;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'session_id', @session_id;

        PRINT 'Executing session termination path. mode: '
        + @mode
        + ', start_version: '
        + CAST(@start_version AS nvarchar(10))
        + ', end_version: '
        + CAST(@end_version AS nvarchar(10))
        + ', session_id: '
        + CAST(@session_id AS nvarchar(128))

        IF @mode = 'upgrade' OR @mode = 'validate'
            BEGIN
                IF 1 BETWEEN @start_version AND @end_version
                    EXEC [mgmt_xtinfra].[sp_infra_killsession_migrationtask_0001] @mode, @session_id;
            END
        ELSE IF @mode = 'downgrade'
            BEGIN
                THROW 50000, 'Downgrade option is no longer valid for kill session procedure.', 1;
            END

        --- add log entry for our job
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';
    END TRY
    BEGIN CATCH
        --- add log entry for our job
        DECLARE @error_message nvarchar(4000) = ERROR_MESSAGE();
        DECLARE @error_severity int = ERROR_SEVERITY();
        DECLARE @error_state int = ERROR_STATE();
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'error_message', @error_message;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'error_severity', @error_severity;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'error_state', @error_state;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'failure';
        --- then throw again to forward error
        THROW;
    END CATCH
END
GO

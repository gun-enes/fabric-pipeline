/*
Description: Deletes gatherstats schedule

Author:
jyothish.b@allianz.com
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_gatherstats_schedule_delete]
    @key [nvarchar](100),
    @workspace_name [nvarchar](10)
AS
BEGIN
    DECLARE @proc_name nvarchar(128) = 'sp_infra_gatherstats_schedule_delete';
    DECLARE @log_detail_group uniqueidentifier = NEWID();

    -- directly giving a variable named @key as the @value parameter of the logging sp causes an error
    DECLARE @schedule_key [nvarchar](100) = @key
    BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
        @log_detail_group, 'key', @schedule_key;

        DELETE FROM [mgmt_xtinfra].[infra_schedule]
        WHERE [key] = @key;
        DELETE FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
        WHERE [infra_schedule_key] = @key;
        DECLARE
            @sql_stmt nvarchar(512) = 'EXECUTE [mgmt_xtinfra].[sp_infra_trigger_pipeline] '
            + QUOTENAME(@workspace_name, '''')
            + ', ''schedule_created'';';
        EXECUTE sp_executesql @sql_stmt;

        -- complete log
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'success';

    END TRY
    BEGIN CATCH
        --- add log entry for our job
        DECLARE @error_message nvarchar(4000) = ERROR_MESSAGE();
        DECLARE @error_severity int = ERROR_SEVERITY();
        DECLARE @error_state int = ERROR_STATE();

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_message', @error_message;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_severity', @error_severity;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_state', @error_state;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'failure';
        --- then throw again to forward error
        THROW;
    END CATCH
END
GO

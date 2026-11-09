/*
Description: Creates a schedule

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_schedule_create]
    @key [nvarchar](100),
    @schedule_action [nvarchar](100),
    @hour [int],
    @day_of_month [nvarchar](100),
    @month [nvarchar](100),
    @day_of_week [nvarchar](100),
    @priority [int],
    @workspace_name [nvarchar](10)
AS
BEGIN
    DECLARE @requestor nvarchar(128) = SESSION_USER;
    DECLARE @proc_name nvarchar(128) = 'sp_infra_schedule_create';

    -- log details
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @now datetime = GETDATE();

    BEGIN TRY
        -- directly giving a variable named @key as the @value parameter of the logging sp causes an error
        DECLARE @schedule_key [nvarchar](100) = @key
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'key', @schedule_key;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'schedule_action', @schedule_action;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'hour', @hour;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'day_of_month', @day_of_month;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'month', @month;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'day_of_week', @day_of_week;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'priority', @priority;

        IF @schedule_action <> 'start' AND @schedule_action <> 'stop'
            THROW 50000, 'Invalid schedule_action type.', 1;

        IF @hour < 0 OR @hour > 23
            THROW 50000, 'Invalid hour parameter.', 1;

        IF [mgmt_xtinfra].[InfraValidateCrontabMonth](@month) = 0
            THROW 50000, 'Invalid month parameter.', 1;

        IF [mgmt_xtinfra].[InfraValidateCrontabDayOfMonth](@day_of_month) = 0
            THROW 50000, 'Invalid day_of_month parameter.', 1;

        IF [mgmt_xtinfra].[InfraValidateCrontabDayOfWeek](@day_of_week) = 0
            THROW 50000, 'Invalid day_of_week parameter.', 1;

        DECLARE @crontab nvarchar(305) = '0 ' + CAST(@hour AS nvarchar(2)) + ' ' + @day_of_month + ' ' + @month + ' ' + @day_of_week;

        IF EXISTS (
            SELECT 1
            FROM [mgmt_xtinfra].[infra_schedule]
            WHERE [key] = @key
        )
            THROW 50000, 'An entry with the given key already exists.', 1;

        INSERT INTO [mgmt_xtinfra].[infra_schedule]
        ([key], [crontab], [hour], [day_of_month], [month], [day_of_week], [schedule_action], [priority], [created_at], [requestor])
        VALUES
        (@key, @crontab, @hour, @day_of_month, @month, @day_of_week, @schedule_action, @priority, @now, @requestor);

        DECLARE
            @sql_stmt nvarchar(512) = 'EXECUTE [mgmt_xtinfra].[sp_infra_trigger_pipeline] '
            + QUOTENAME(@workspace_name, '''')
            + ', ''schedule_created'';';
        EXECUTE sp_executesql @sql_stmt;

        -- complete log
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

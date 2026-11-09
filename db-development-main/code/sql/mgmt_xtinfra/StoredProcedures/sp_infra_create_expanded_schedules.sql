/*
Description: Creates expanded schedule table

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_create_expanded_schedules]
    @expanded_schedules [nvarchar](MAX)
AS
BEGIN
    DECLARE @proc_name nvarchar(128) = 'sp_infra_create_expanded_schedules';
    DECLARE @log_detail_group uniqueidentifier = NEWID();

    BEGIN TRY

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        IF OBJECT_ID('[mgmt_xtinfra].[temp_schedule]') IS NOT NULL
            DROP TABLE [mgmt_xtinfra].[temp_schedule];

        -- create temporary table to add new schedules on
        CREATE TABLE [mgmt_xtinfra].[temp_schedule]
        (
            [key] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
            [schedule_action] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
            [schedule_time] [datetime] NOT NULL,
            [created_at] [datetime] NOT NULL,
            [requestor] [nvarchar](100) NULL
        ) WITH (DISTRIBUTION = REPLICATE);

        -- add new schedule data
        INSERT INTO [mgmt_xtinfra].[temp_schedule] ([key], [schedule_action], [schedule_time], [created_at], [requestor])
        SELECT
            [key],
            [schedule_action],
            [schedule_time],
            GETDATE() AS [created_at],
            [requestor]
        FROM
            OPENJSON (@expanded_schedules)
            WITH (
                [key] [nvarchar](100),
                [schedule_action] nvarchar(100),
                [schedule_time] datetime,
                [requestor] nvarchar(100)
            );

        -- switch original table with temporary table
        ALTER TABLE [mgmt_xtinfra].[temp_schedule] SWITCH TO [mgmt_xtinfra].[infra_expanded_schedule] WITH (TRUNCATE_TARGET = ON);

        -- drop temporary table
        DROP TABLE [mgmt_xtinfra].[temp_schedule]

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

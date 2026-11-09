/*
Description:
This stored procedure is used to run workloadgroup tasks to a specific version.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version]
    (
        @mode [nvarchar](32),
        @start_version [int],
        @end_version [int],
        @group_name [nvarchar](128),
        @min_percentage_resource [int],
        @cap_percentage_resource [int],
        @request_min_resource_grant_percent [decimal](5, 2),
        @request_max_resource_grant_percent [decimal](5, 2),
        @importance [nvarchar](128),
        @query_execution_timeout_sec [int]
    )
AS
BEGIN
    --- define required variables
    DECLARE @proc_name nvarchar(128) = 'sp_infra_workloadgroup_run_to_version';
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(512);

    BEGIN TRY
        --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'start_version', @start_version;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'end_version', @end_version;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'group_name', @group_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'min_percentage_resource', @min_percentage_resource;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'cap_percentage_resource', @cap_percentage_resource;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'request_min_resource_grant_percent', @request_min_resource_grant_percent;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'request_max_resource_grant_percent', @request_max_resource_grant_percent;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'importance', @importance;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'query_execution_timeout_sec', @query_execution_timeout_sec;

        PRINT 'Executing workloadgroup migration path. mode: '
        + @mode
        + ', start_version: '
        + CAST(@start_version AS nvarchar(10))
        + ', end_version: '
        + CAST(@end_version AS nvarchar(10))
        + ', group_name: '
        + @group_name
        + ', min_percentage_resource: '
        + CAST(@min_percentage_resource AS nvarchar(10))
        + ', cap_percentage_resource: '
        + CAST(@cap_percentage_resource AS nvarchar(10))
        + ', request_min_resource_grant_percent: '
        + CAST(@request_min_resource_grant_percent AS nvarchar(10))
        + ', request_max_resource_grant_percent: '
        + ISNULL(CAST(@request_max_resource_grant_percent AS nvarchar(10)), '')
        + ', importance: '
        + ISNULL(@importance, '')
        + ', query_execution_timeout_sec: '
        + ISNULL(CAST(@query_execution_timeout_sec AS nvarchar(10)), '');

        IF @mode = 'upgrade' OR @mode = 'validate'
            BEGIN
                IF 1 BETWEEN @start_version AND @end_version
                    EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_migrationtask_0001]
                        @mode,
                        @group_name,
                        @min_percentage_resource,
                        @cap_percentage_resource,
                        @request_min_resource_grant_percent,
                        @request_max_resource_grant_percent,
                        @importance,
                        @query_execution_timeout_sec;
            END
        ELSE IF @mode = 'downgrade'
            BEGIN
                IF 1 BETWEEN @end_version AND @start_version
                    EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_migrationtask_0001]
                        @mode,
                        @group_name,
                        @min_percentage_resource,
                        @cap_percentage_resource,
                        @request_min_resource_grant_percent,
                        @request_max_resource_grant_percent,
                        @importance,
                        @query_execution_timeout_sec;
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

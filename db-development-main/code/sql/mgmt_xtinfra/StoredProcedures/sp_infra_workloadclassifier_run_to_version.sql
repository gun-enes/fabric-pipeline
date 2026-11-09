/*
Description:
This stored procedure is used to run workloadclassifier tasks to a specific version.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workloadclassifier_run_to_version]
    (
        @mode [nvarchar](32),
        @start_version [int],
        @end_version [int],
        @classifier_name [nvarchar](128),
        @workload_group [nvarchar](128),
        @member_name [nvarchar](128),
        @wlm_label [nvarchar](255),
        @wlm_context [nvarchar](255),
        @start_time [nvarchar](5),
        @end_time [nvarchar](5),
        @importance [nvarchar](128)
    )
AS
BEGIN
    --- define required variables
    DECLARE @proc_name nvarchar(128) = 'sp_infra_workloadclassifier_run_to_version';
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(512);

    BEGIN TRY

        --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'start_version', @start_version;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'end_version', @end_version;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'classifier_name', @classifier_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workload_group', @workload_group;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'member_name', @member_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'wlm_label', @wlm_label;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'wlm_context', @wlm_context;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'start_time', @start_time;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'end_time', @end_time;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'importance', @importance;

        PRINT 'Executing workloadclassifier migration path. mode: '
        + @mode
        + ', start_version: '
        + CAST(@start_version AS nvarchar(10))
        + ', end_version: '
        + CAST(@end_version AS nvarchar(10))
        + ', classifier_name: '
        + @classifier_name
        + ', workload_group: '
        + @workload_group
        + ', member_name: '
        + ISNULL(@member_name, '')
        + ', wlm_label: '
        + ISNULL(@wlm_label, '')
        + ', wlm_context: '
        + ISNULL(@wlm_context, '')
        + ', start_time: '
        + ISNULL(@start_time, '')
        + ', end_time: '
        + ISNULL(@end_time, '')
        + ', importance: '
        + ISNULL(@importance, '');

        IF @mode = 'upgrade' OR @mode = 'validate'
            BEGIN
                IF 1 BETWEEN @start_version AND @end_version
                    EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_migrationtask_0001]
                        @mode,
                        @classifier_name,
                        @workload_group,
                        @member_name,
                        @wlm_label,
                        @wlm_context,
                        @start_time,
                        @end_time,
                        @importance;
            END
        ELSE IF @mode = 'downgrade'
            BEGIN
                IF 1 BETWEEN @end_version AND @start_version
                    EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_migrationtask_0001]
                        @mode,
                        @classifier_name,
                        @workload_group,
                        @member_name,
                        @wlm_label,
                        @wlm_context,
                        @start_time,
                        @end_time,
                        @importance;
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

/*
Description:
This stored procedure is used to run rlspolicy tasks to a specific version.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_rlspolicy_run_to_version]
    (
        @mode [nvarchar](32),
        @start_version int,
        @end_version int,
        @schema_name [nvarchar](42),
        @predicate_function_name [nvarchar](128),
        @table_name [nvarchar](78),
        @parameter_list [nvarchar](4000)
    )
AS
BEGIN
    --- define required variables
    DECLARE @proc_name nvarchar(128) = 'sp_infra_rlspolicy_run_to_version';
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(512);
    DECLARE @combined_policy_name nvarchar(128) = [mgmt_xtinfra].[InfraGetRlsPolicyName](@schema_name, @table_name);

    BEGIN TRY

        --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'start_version', @start_version;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'end_version', @end_version;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'schema_name', @schema_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'combined_policy_name', @combined_policy_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'predicate_function_name', @predicate_function_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'table_name', @table_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'parameter_list', @parameter_list;

        PRINT 'Executing rlspolicy migration path. mode: '
        + @mode
        + ', start_version: '
        + CAST(@start_version AS nvarchar(10))
        + ', end_version: '
        + CAST(@end_version AS nvarchar(10))
        + ', schema_name: '
        + @schema_name
        + ', combined_policy_name: '
        + @combined_policy_name
        + ', predicate_function_name: '
        + @predicate_function_name
        + ', table_name: '
        + @table_name
        + ', parameter_list: '
        + @parameter_list;

        IF @mode = 'upgrade' OR @mode = 'validate'
            BEGIN
                IF 1 BETWEEN @start_version AND @end_version
                    EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_migrationtask_0001]
                        @mode, @schema_name, @combined_policy_name, @predicate_function_name, @table_name, @parameter_list;
            END
        ELSE IF @mode = 'downgrade'
            BEGIN
                IF 1 BETWEEN @end_version AND @start_version
                    EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_migrationtask_0001]
                        @mode, @schema_name, @combined_policy_name, @predicate_function_name, @table_name, @parameter_list;
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

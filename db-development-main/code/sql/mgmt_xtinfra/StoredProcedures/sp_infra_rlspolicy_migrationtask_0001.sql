/*
Description:
This stored procedure is used to create or delete RLS policy based on the parameters.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_rlspolicy_migrationtask_0001]
    (
        @mode [nvarchar](32),
        @schema_name [nvarchar](42),
        @policy_name [nvarchar](128),
        @predicate_function_name [nvarchar](128),
        @table_name [nvarchar](128),
        @parameter_list [nvarchar](4000)
    )
AS
BEGIN

    --- use this to easily assign the migration task id for this task
    DECLARE @version_object_type nvarchar(128) = 'rlspolicy';
    DECLARE @version_object_name nvarchar(128) = @policy_name;
    DECLARE @proc_name nvarchar(128) = 'sp_infra_rlspolicy_migrationtask_0001';

    --- define required variables
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(512);

    BEGIN TRY

        --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'schema_name', @schema_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'policy_name', @policy_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'predicate_function_name', @predicate_function_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'table_name', @table_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'parameter_list', @parameter_list;

    --- calc target version
    -- on downgrades we will set the target version to the previous version
    DECLARE @migrationtask_id int = [mgmt_xtinfra].InfraGetMigrationTaskId(@proc_name);
    DECLARE @version_object_version int = @migrationtask_id;
    IF @mode = 'downgrade'
        SET @version_object_version = @migrationtask_id - 1;

        --- validate if we are in the correct version range to apply our change
        DECLARE @can_migrate bit = 0;
        EXEC [mgmt_xtinfra].[sp_infra_get_migrationtask_canmigrate_object]
            @version_object_type, @version_object_name, @mode, @migrationtask_id, @can_migrate OUTPUT;
        IF @can_migrate = 1
            BEGIN
                IF @mode = 'upgrade'
                    BEGIN
                        PRINT 'Running migration in upgrade mode: ' + @proc_name;
                        EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_mt_create]
                            @schema_name,
                            @policy_name,
                            @predicate_function_name,
                            @table_name,
                            @parameter_list;
                    END
                ELSE IF @mode = 'downgrade'
                    BEGIN
                        PRINT 'Running migration in downgrade mode: ' + @proc_name;

                        EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_mt_delete]
                            @schema_name, @policy_name;

                    END
                ELSE IF @mode = 'validate'
                    BEGIN
                        PRINT 'Running migration in validate mode: ' + @proc_name;

                        EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_mt_validate]
                            @schema_name, @policy_name;

                    END
                ELSE
                    THROW 50000, 'Invalid mode specified for migration task.', 1;

                --- persist object version
                EXEC [mgmt_xtinfra].[sp_infra_set_object_version]
                    @version_object_type, @version_object_name, @version_object_version;
                --- add log entry for our job
                EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';
            END
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

/*
Description:
This stored procedure is used to create or delete Workload Classifier based on the parameters.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workloadclassifier_migrationtask_0001]
    (
        @mode [nvarchar](32),
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

    --- use this to easily assign the migration task id for this task
    DECLARE @version_object_type nvarchar(128) = 'workloadclassifier';
    DECLARE @version_object_name nvarchar(128) = @classifier_name;
    DECLARE @proc_name nvarchar(128) = 'sp_infra_workloadclassifier_migrationtask_0001';

    --- define required variables
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(512);

    --- calc target version
    -- on downgrades we will set the target version to the previous version
    DECLARE @migrationtask_id int = [mgmt_xtinfra].InfraGetMigrationTaskId(@proc_name);
    DECLARE @version_object_version int = @migrationtask_id;
    IF @mode = 'downgrade'
        SET @version_object_version = @migrationtask_id - 1;

    BEGIN TRY

        --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'classifier_name', @classifier_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'workload_group', @workload_group;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'member_name', @member_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'wlm_label', @wlm_label;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'wlm_context', @wlm_context;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'start_time', @start_time;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'end_time', @end_time;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'importance', @importance;

        --- validate if we are in the correct version range to apply our change
        DECLARE @can_migrate bit = 0;
        EXEC [mgmt_xtinfra].[sp_infra_get_migrationtask_canmigrate_object]
            @version_object_type, @version_object_name, @mode, @migrationtask_id, @can_migrate OUTPUT;
        IF @can_migrate = 1
            BEGIN
                IF @mode = 'upgrade'
                    BEGIN
                        PRINT 'Running migration in upgrade mode: ' + @proc_name;
                        EXEC [mgmt_xtinfra].[sp_infra_workload_classifier_create_or_update]
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
                        PRINT 'Running migration in downgrade mode: ' + @proc_name;
                        IF
                            EXISTS (
                                SELECT 1
                                FROM [sys].[workload_management_workload_classifiers]
                                WHERE
                                    [name] = @classifier_name
                            )
                            BEGIN
                                PRINT 'Deleting workload classifier: ' + @classifier_name
                                SET @sql_stmt = 'DROP WORKLOAD CLASSIFIER ' + QUOTENAME(@classifier_name);
                                EXEC (@sql_stmt);
                            END
                    END
                ELSE IF @mode = 'validate'
                    BEGIN
                        PRINT 'Running migration in validate mode: ' + @proc_name;

                        IF
                            NOT EXISTS (
                                SELECT 1
                                FROM [sys].[workload_management_workload_classifiers]
                                WHERE
                                    [name] = @classifier_name
                            )
                            THROW 50000, 'Validation failed. Workload classifier does not exist.', 1;
                    END
                ELSE
                    THROW 50000, 'Invalid mode specified for migration task.', 1;

                --- persist object version
                EXEC [mgmt_xtinfra].[sp_infra_set_object_version]
                    @version_object_type, @version_object_name, @version_object_version;
                --- add log entry for our job
                EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';
            END
        ELSE
            BEGIN
                IF @mode = 'upgrade'
                    BEGIN
                        PRINT 'Running migration in upgrade (alter) mode: ' + @proc_name;
                        EXEC [mgmt_xtinfra].[sp_infra_workload_classifier_create_or_update]
                            @classifier_name,
                            @workload_group,
                            @member_name,
                            @wlm_label,
                            @wlm_context,
                            @start_time,
                            @end_time,
                            @importance;
                    END
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

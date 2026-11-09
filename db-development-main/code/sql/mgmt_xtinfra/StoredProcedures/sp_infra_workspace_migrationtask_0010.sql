/*
Description:
Adds select permission on schedule views to workspace writers.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workspace_migrationtask_0010] (
    @mode [nvarchar](32),
    @workspace_name [nvarchar](10)
) AS
BEGIN
    ---------------------------------------
    --- TASK INITIALIZATION STARTS HERE ---
    ---------------------------------------

    DECLARE @proc_name nvarchar(128) = 'sp_infra_workspace_migrationtask_0010';

    DECLARE @infra_object_type nvarchar(128) = 'workspace';
    DECLARE @infra_object_name nvarchar(256) = @workspace_name;
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(1024);

    BEGIN TRY
        --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workspace_name', @workspace_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;

        -- on downgrades we will set the target version to the previous version
        DECLARE @migrationtask_id int = [mgmt_xtinfra].InfraGetMigrationTaskId(@proc_name);
        DECLARE @infra_object_version int = @migrationtask_id;
        IF @mode = 'downgrade'
            SET @infra_object_version = @migrationtask_id - 1

        DECLARE @view_workspace_schedule nvarchar(128) = QUOTENAME(@workspace_name) + '.[v_schedule]';
        DECLARE @view_workspace_expanded_schedule nvarchar(128) = QUOTENAME(@workspace_name) + '.[v_expanded_schedule]';
        DECLARE @writer_role_name nvarchar(128) = QUOTENAME([mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'writer'));

        ---------------------------------------
        --- TASK INITIALIZATION ENDS HERE ---
        ---------------------------------------

        --- validate if we are in the correct version range to apply our change
        DECLARE @can_migrate bit = 0;
        EXEC [mgmt_xtinfra].[sp_infra_get_migrationtask_canmigrate_object]
            @infra_object_type, @infra_object_name, @mode, @migrationtask_id, @can_migrate OUTPUT;

        IF @can_migrate = 1 BEGIN
            IF @mode = 'upgrade'
                BEGIN
                    PRINT 'Running migration in upgrade mode: ' + @proc_name;

                    SET
                        @sql_stmt = N'GRANT SELECT ON '
                        + @view_workspace_schedule
                        + ' TO ' + @writer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'GRANT SELECT ON '
                        + @view_workspace_expanded_schedule
                        + ' TO ' + @writer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;
                END
            ELSE IF @mode = 'downgrade'
                BEGIN
                    PRINT 'Running migration in downgrade mode: ' + @proc_name;
                    IF OBJECT_ID(@view_workspace_schedule, 'V') IS NOT NULL
                        BEGIN
                            SET
                                @sql_stmt = N'REVOKE SELECT ON '
                                + @view_workspace_schedule
                                + ' TO ' + @writer_role_name + ';';
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    IF OBJECT_ID(@view_workspace_expanded_schedule, 'V') IS NOT NULL
                        BEGIN
                            SET
                                @sql_stmt = N'REVOKE SELECT ON '
                                + @view_workspace_expanded_schedule
                                + ' TO ' + @writer_role_name + ';';
                            EXEC [sp_executesql] @sql_stmt;
                        END
                END
            ELSE IF @mode = 'validate'
                BEGIN
                    PRINT 'Running migration in validate mode: ' + @proc_name;
                    IF
                        HAS_PERMS_BY_NAME(
                            @view_workspace_schedule,
                            'OBJECT',
                            'SELECT'
                        ) = 0
                        THROW 50000,
                        'Role does not have SELECT permission on [v_schedule]',
                        1;
                    IF
                        HAS_PERMS_BY_NAME(
                            @view_workspace_expanded_schedule,
                            'OBJECT',
                            'SELECT'
                        ) = 0
                        THROW 50000,
                        'Role does not have SELECT permission on [v_expanded_schedule]',
                        1;
                END
            ELSE
                THROW 50000, 'Invalid mode specified for migration task.', 1;

                --- persist object version
            EXEC [mgmt_xtinfra].[sp_infra_set_object_version]
                @infra_object_type, @infra_object_name, @infra_object_version
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

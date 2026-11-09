/*
Description:
This stored procedure is used to kill the session for self service.

Author:
jyothish.b@allianz.com
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_killsession_migrationtask_0001] @mode [nvarchar](32),@session_id [nvarchar](128) AS
BEGIN

    --- use this to easily assign the migration task id for this task
    DECLARE @version_object_type nvarchar(128) = 'killsession';
    DECLARE @version_object_name nvarchar(128) = @session_id;
    DECLARE @proc_name nvarchar(128) = 'sp_infra_killsession_migrationtask_0001';

    --- define required variables
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(512);

    --- calc target version
    -- on downgrades we will set the target version to the previous version
    DECLARE @migrationtask_id int = [mgmt_xtinfra].InfraGetMigrationTaskId(@proc_name);
    DECLARE @version_object_version int = @migrationtask_id;
    IF @mode = 'downgrade'
        SET @version_object_version = @migrationtask_id - 1;

    --- assign logging details already here
    BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'session_id', @session_id;

        --- validate if we are in the correct version range to apply our change
        DECLARE @can_migrate bit = 0;
        EXEC [mgmt_xtinfra].[sp_infra_get_migrationtask_canmigrate_object]
            @version_object_type, @version_object_name, @mode, @migrationtask_id, @can_migrate OUTPUT;
        print @can_migrate
        IF @can_migrate = 1
            BEGIN
                IF @mode = 'upgrade'
                    BEGIN
                        PRINT 'Running migration in kill session in upgrade mode: ' + @proc_name;

                        SET @sql_stmt = N'KILL '''+ @session_id + '''';
                        IF
                            EXISTS (
                                SELECT 1
                                FROM [sys].[dm_pdw_exec_sessions]
                                WHERE
                                    [app_name] not in ('Internal','DWShellDb')
                                    AND [status] <> 'Closed'
                                    AND [session_id] = @session_id
                            )
                            BEGIN
                                PRINT 'Killing session: ' + @session_id
                                EXEC [sp_executesql] @sql_stmt;
                            END
                        ELSE
                            BEGIN
                                PRINT 'Requested session for terminating has not been present in DB ...';
                                THROW 50000,
                                'Requested session for terminating has not been present in DB.',
                                1;
                            END
                    END
                ELSE IF @mode = 'validate'
                    BEGIN
                        PRINT 'Running migration in validate mode: ' + @proc_name;

                        IF
                            NOT EXISTS (
                                SELECT 1
                                FROM [sys].[dm_pdw_exec_sessions]
                                WHERE
                                    [app_name] not in ('Internal','DWShellDb')
                                    AND [status] <> 'Closed'
                                    AND [session_id] = @session_id
                            )
                            THROW 50000, 'Validation failed. Session does not exist.', 1;

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
GO

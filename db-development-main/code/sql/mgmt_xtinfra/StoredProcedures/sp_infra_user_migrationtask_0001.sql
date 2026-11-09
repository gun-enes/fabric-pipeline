/*
Description:
This stored procedure is used to create or delete user based on the parameters.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_user_migrationtask_0001]
    (
        @mode [nvarchar](32),
        @user_name [nvarchar](128)
    )
AS
BEGIN

    --- use this to easily assign the migration task id for this task
    DECLARE @version_object_type nvarchar(128) = 'user';
    DECLARE @version_object_name nvarchar(128) = @user_name;
    DECLARE @proc_name nvarchar(128) = 'sp_infra_user_migrationtask_0001';

    --- define required variables
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(512);

    BEGIN TRY
        --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'user_name', @user_name;

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

                        -- We unfortunately need to create the user first to check if the SQL user corresponds to an Entra group
                        -- We will then drop the user if it does not match an Entra group
                        SET @sql_stmt = N'CREATE USER ' + QUOTENAME(@user_name) + ' FROM EXTERNAL PROVIDER;';
                        IF
                            NOT EXISTS (
                                SELECT 1
                                FROM [sys].[database_principals]
                                WHERE
                                    [name] = @user_name
                                    AND [type] = 'X'
                            )
                            BEGIN
                                PRINT 'Creating user: ' + @user_name
                                EXEC [sp_executesql] @sql_stmt;
                            END

                        -- https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-principals-transact-sql?view=azure-sqldw-latest
                        -- type = 'X' -> External group from Microsoft Entra group or applications
                        -- type = 'E' -> External user from Microsoft Entra ID
                        IF
                            NOT EXISTS (
                                SELECT 1
                                FROM [sys].[database_principals]
                                WHERE
                                    [name] = @user_name
                                    AND [type] = 'X'
                            )
                            BEGIN
                                PRINT 'User does not correspond to an Entra group, deleting user...'
                                SET @sql_stmt = N'DROP USER ' + QUOTENAME(@user_name);
                                EXEC [sp_executesql] @sql_stmt;
                                THROW 50000,
                                'User does not correspond to an Entra group.',
                                1;
                            END
                    END
                ELSE IF @mode = 'downgrade'
                    BEGIN
                        PRINT 'Running migration in downgrade mode: ' + @proc_name;

                        SET @sql_stmt = N'DROP USER ' + QUOTENAME(@user_name) + ';';

                        IF EXISTS (
                            SELECT 1
                            FROM [sys].[database_principals]
                            WHERE
                                [name] = @user_name
                                AND [type] = 'X'
                            )
                            BEGIN
                                PRINT 'Deleting user: ' + @user_name;
                                EXEC [sp_executesql] @sql_stmt;
                            END
                    END
                ELSE IF @mode = 'validate'
                    BEGIN
                        PRINT 'Running migration in validate mode: ' + @proc_name;

                        IF
                            NOT EXISTS (
                                SELECT 1
                                FROM [sys].[sysusers] AS [su]
                                WHERE
                                    [su].[name] = @user_name
                                    AND [su].[issqlrole] = 0
                            )
                            THROW 50000, 'Validation failed. User does not exist.', 1;

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

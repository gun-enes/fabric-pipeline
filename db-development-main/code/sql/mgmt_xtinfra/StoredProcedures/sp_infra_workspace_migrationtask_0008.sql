/*
Description:
Adds necessary permissions to schema-deployer for session termination in DB.

Author:
jyothish.b@allianz.com
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_workspace_migrationtask_0008] @mode [nvarchar](32),@workspace_name [nvarchar](10) AS
BEGIN
    ---------------------------------------
    --- TASK INITIALIZATION STARTS HERE ---
    ---------------------------------------

    DECLARE @proc_name nvarchar(128) = 'sp_infra_workspace_migrationtask_0008';

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

        DECLARE
            @sp_workspace_killsession_order_create_or_update_name nvarchar(128)
            = QUOTENAME(@workspace_name) + '.[sp_workspace_killsession_order_create_or_update]';
        DECLARE @mgmt_sp_infra_killsession_order_create_or_update nvarchar(128) = '[mgmt_xtinfra].[sp_infra_killsession_order_create_or_update]';
        DECLARE @mgmt_tbl_infra_orders_details_killsessions nvarchar(128) = '[mgmt_xtinfra].[infra_orders_details_killsessions]';
        DECLARE @deployer_role_name nvarchar(128) = QUOTENAME([mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer'));

        ---------------------------------------
        --- TASK INITIALIZATION ENDS HERE ---
        ---------------------------------------

        --- validate if we are in the correct version range to apply our change
        DECLARE @can_migrate bit = 0;
        EXEC [mgmt_xtinfra].[sp_infra_get_migrationtask_canmigrate_object]
            @infra_object_type, @infra_object_name, @mode, @migrationtask_id, @can_migrate OUTPUT;

        IF @can_migrate = 1
            BEGIN
                IF @mode = 'upgrade'
                    BEGIN
                        PRINT 'Running migration in upgrade mode: ' + @proc_name;

                        -- add session management stored procedures
                        IF OBJECT_ID(@sp_workspace_killsession_order_create_or_update_name, 'P') IS NULL
                            BEGIN
                                SET
                                    @sql_stmt = N'CREATE PROCEDURE '
                                    + @sp_workspace_killsession_order_create_or_update_name
                                    + ' @session_id [nvarchar](128) AS '
                                    + N'EXEC '
                                    + @mgmt_sp_infra_killsession_order_create_or_update
                                    + ' @session_id,'
                                    + QUOTENAME(@workspace_name, '''');
                                EXEC [sp_executesql] @sql_stmt;
                            END
                        -- grant exec permissions for schema-deployer
                        SET
                            @sql_stmt
                            = N'GRANT EXECUTE ON '
                            + @sp_workspace_killsession_order_create_or_update_name
                            + ' TO '
                            + @deployer_role_name
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt = N'GRANT EXECUTE ON '
                            + @mgmt_sp_infra_killsession_order_create_or_update
                            + ' TO ' + @deployer_role_name + ';';
                        EXEC [sp_executesql] @sql_stmt;

                        -- grant insert permissions for schema-deployer on session details
                        SET
                            @sql_stmt = N'GRANT INSERT ON '
                            + @mgmt_tbl_infra_orders_details_killsessions
                            + ' TO '
                            + @deployer_role_name + ';';
                        EXEC [sp_executesql] @sql_stmt;

                    END
                ELSE IF @mode = 'downgrade'
                    BEGIN
                        PRINT 'Running migration in downgrade mode: ' + @proc_name;

                        --- drop session management stored procedures
                        IF OBJECT_ID(@sp_workspace_killsession_order_create_or_update_name, 'P') IS NOT NULL
                            BEGIN
                                SET
                                    @sql_stmt = N'DROP PROCEDURE ' + @sp_workspace_killsession_order_create_or_update_name;
                                EXEC [sp_executesql] @sql_stmt;
                            END

                        -- revoke execute permissions for schema-deployer
                        SET
                            @sql_stmt
                            = N'REVOKE EXECUTE ON '
                            + @mgmt_sp_infra_killsession_order_create_or_update
                            + ' FROM '
                            + @deployer_role_name
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                        -- revoke insert permissions for schema-deployer on session details
                        SET
                            @sql_stmt
                            = N'REVOKE INSERT ON '
                            + @mgmt_tbl_infra_orders_details_killsessions
                            + ' FROM '
                            + @deployer_role_name
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;
                    END
                ELSE IF @mode = 'validate'
                    BEGIN
                        PRINT 'Running migration in validate mode: ' + @proc_name;

                        --- validate session management SP
                        IF
                            OBJECT_ID(@sp_workspace_killsession_order_create_or_update_name, 'P') IS NULL
                            THROW 50000, 'Session management SP does not exist.', 1;

                        --- validate permissions
                        IF
                            HAS_PERMS_BY_NAME(
                                @sp_workspace_killsession_order_create_or_update_name,
                                'OBJECT',
                                'EXECUTE'
                            ) = 0
                            THROW 50000,
                            'Role does not have EXECUTE permission on SP',
                            1;
                        IF
                            HAS_PERMS_BY_NAME(
                                @mgmt_sp_infra_killsession_order_create_or_update, --- I am here
                                'OBJECT',
                                'EXECUTE'
                            ) = 0
                            THROW 50000,
                            'Role does not have EXECUTE permission on [mgmt_xtinfra].[sp_infra_killsession_order_create_or_update]',
                            1;

                        --- session order details table
                        IF HAS_PERMS_BY_NAME(@mgmt_tbl_infra_orders_details_killsessions, 'OBJECT', 'INSERT') = 0
                            THROW 50000,
                            'Role does not have INSERT permission on [mgmt_xtinfra].[infra_orders_details_killsessions]',
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
GO

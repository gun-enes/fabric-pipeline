/*
Description:
Adds necessary permissions to schema-deployer for creating an Rls policy order.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workspace_migrationtask_0003] (
    @mode [nvarchar](32),
    @workspace_name [nvarchar](10)
) AS
BEGIN
    -------------------------------
    --- TASK CONFIG STARTS HERE ---
    -------------------------------

    --- use this to easily assign the migration task id for this task
    DECLARE @version_object_type nvarchar(128) = 'workspace'
    DECLARE @version_object_name nvarchar(256) = @workspace_name
    DECLARE @proc_name nvarchar(128) = 'sp_infra_workspace_migrationtask_0003'
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(1024);

    -----------------------------
    --- TASK CONFIG ENDS HERE ---
    -----------------------------

    BEGIN TRY
        --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workspace_name', @workspace_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;

        --- calc target version
        -- on downgrades we will set the target version to the previous version
        DECLARE @migrationtask_id int = [mgmt_xtinfra].InfraGetMigrationTaskId(@proc_name)
        DECLARE @version_object_version int = @migrationtask_id
        IF @mode = 'downgrade'
            SET @version_object_version = @migrationtask_id - 1
        -- some custom vars
        DECLARE @deployer_role_name nvarchar(128) = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
        DECLARE
            @sp_workspace_rlspolicy_order_create_or_update_name nvarchar(128)
            = QUOTENAME(@workspace_name) + '.[sp_workspace_rlspolicy_order_create_or_update]';
        DECLARE
            @sp_workspace_rlspolicy_order_delete_name nvarchar(128)
            = QUOTENAME(@workspace_name) + '.[sp_workspace_rlspolicy_order_delete]';
        DECLARE
            @mgmt_sp_infra_rlspolicy_order_create_or_update nvarchar(128) = '[mgmt_xtinfra].[sp_infra_rlspolicy_order_create_or_update]';
        DECLARE @mgmt_sp_infra_rlspolicy_order_delete nvarchar(128) = '[mgmt_xtinfra].[sp_infra_rlspolicy_order_delete]';

        --- validate if we are in the correct version range to apply our change
        DECLARE @can_migrate bit = 0
        EXEC [mgmt_xtinfra].[sp_infra_get_migrationtask_canmigrate_object]
            @version_object_type, @version_object_name, @mode, @migrationtask_id, @can_migrate OUTPUT

        IF @can_migrate = 1
            BEGIN
                IF @mode = 'upgrade'
                    BEGIN
                        PRINT 'Running migration in upgrade mode: ' + @proc_name;

                        IF OBJECT_ID(@sp_workspace_rlspolicy_order_create_or_update_name, 'P') IS NULL
                            BEGIN
                            -- add rls policy management stored procedures
                                SET
                                    @sql_stmt = N'CREATE PROCEDURE '
                                    + @sp_workspace_rlspolicy_order_create_or_update_name
                                    + ' @schema_name [nvarchar](42), '
                                    + '@predicate_function_name [nvarchar](128), '
                                    + '@table_name [nvarchar](78), '
                                    + '@parameter_list [nvarchar](4000) AS '
                                    + N'EXEC '
                                    + @mgmt_sp_infra_rlspolicy_order_create_or_update
                                    + ' @schema_name, '
                                    + '@predicate_function_name, '
                                    + '@table_name, '
                                    + '@parameter_list;'
                                EXEC [sp_executesql] @sql_stmt;
                            END

                        IF OBJECT_ID(@sp_workspace_rlspolicy_order_delete_name, 'P') IS NULL
                            BEGIN
                                SET
                                    @sql_stmt = N'CREATE PROCEDURE '
                                    + @sp_workspace_rlspolicy_order_delete_name
                                    + ' @schema_name [nvarchar](42), '
                                    + '@table_name [nvarchar](78) AS '
                                    + N'EXEC '
                                    + @mgmt_sp_infra_rlspolicy_order_delete
                                    + ' @schema_name, '
                                    + '@table_name;'
                                EXEC [sp_executesql] @sql_stmt;
                            END

                        SET
                            @sql_stmt
                            = N'GRANT EXECUTE ON '
                            + @sp_workspace_rlspolicy_order_create_or_update_name
                            + ' TO '
                            + QUOTENAME(@deployer_role_name)
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt
                            = N'GRANT EXECUTE ON '
                            + @sp_workspace_rlspolicy_order_delete_name
                            + ' TO '
                            + QUOTENAME(@deployer_role_name)
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt = N'GRANT EXECUTE ON ' + @mgmt_sp_infra_rlspolicy_order_create_or_update + ' TO ' + QUOTENAME(@deployer_role_name) + ';';
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt = N'GRANT EXECUTE ON ' + @mgmt_sp_infra_rlspolicy_order_delete + ' TO ' + QUOTENAME(@deployer_role_name) + ';';
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt = N'GRANT EXECUTE ON [mgmt_xtinfra].[sp_infra_job_log_execution] TO ' + QUOTENAME(@deployer_role_name) + ';';
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt = N'GRANT EXECUTE ON [mgmt_xtinfra].[sp_infra_job_log_execution_details] TO ' + QUOTENAME(@deployer_role_name) + ';';
                        EXEC [sp_executesql] @sql_stmt;

                        -- grant insert permissions for schema-deployer on logging tables
                        SET
                            @sql_stmt = N'GRANT INSERT ON [mgmt_xtinfra].[infra_job_master_v2_details] TO ' + QUOTENAME(@deployer_role_name) + ';';
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt = N'GRANT INSERT ON [mgmt_xtinfra].[infra_job_master_v2] TO ' + QUOTENAME(@deployer_role_name) + ';';
                        EXEC [sp_executesql] @sql_stmt;

                        -- grant insert permissions for schema-deployer on rlspolicy details
                        SET
                            @sql_stmt = N'GRANT INSERT ON [mgmt_xtinfra].[infra_orders_details_rlspolicy] TO ' + QUOTENAME(@deployer_role_name) + ';';
                        EXEC [sp_executesql] @sql_stmt;

                    END
                ELSE IF @mode = 'downgrade'
                    BEGIN
                        PRINT 'Running migration in downgrade mode: ' + @proc_name;

                        --- drop rls policy management stored procedures
                        IF OBJECT_ID(@sp_workspace_rlspolicy_order_create_or_update_name, 'P') IS NOT NULL
                            BEGIN
                                SET
                                    @sql_stmt
                                    = N'DROP PROCEDURE '
                                    + @sp_workspace_rlspolicy_order_create_or_update_name
                                    + ';'
                                EXEC [sp_executesql] @sql_stmt;
                            END

                        IF OBJECT_ID(@sp_workspace_rlspolicy_order_delete_name, 'P') IS NOT NULL
                            BEGIN
                                SET
                                    @sql_stmt
                                    = N'DROP PROCEDURE '
                                    + @sp_workspace_rlspolicy_order_delete_name
                                    + ';'
                                EXEC [sp_executesql] @sql_stmt;
                            END

                        -- revoke execute permissions for schema-deployer
                        SET
                            @sql_stmt
                            = N'REVOKE EXECUTE ON ' + @mgmt_sp_infra_rlspolicy_order_create_or_update + ' FROM '
                            + QUOTENAME(@deployer_role_name)
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt
                            = N'REVOKE EXECUTE ON ' + @mgmt_sp_infra_rlspolicy_order_delete + ' FROM '
                            + QUOTENAME(@deployer_role_name)
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt
                            = N'REVOKE EXECUTE ON [mgmt_xtinfra].[sp_infra_job_log_execution] FROM '
                            + QUOTENAME(@deployer_role_name)
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt
                            = N'REVOKE EXECUTE ON [mgmt_xtinfra].[sp_infra_job_log_execution_details] FROM '
                            + QUOTENAME(@deployer_role_name)
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                        -- revoke insert permissions for schema-deployer on logging tables
                        SET
                            @sql_stmt
                            = N'REVOKE INSERT ON [mgmt_xtinfra].[infra_job_master_v2_details] FROM '
                            + QUOTENAME(@deployer_role_name)
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                        SET
                            @sql_stmt
                            = N'REVOKE INSERT ON [mgmt_xtinfra].[infra_job_master_v2] FROM '
                            + QUOTENAME(@deployer_role_name)
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                        -- revoke insert permissions for schema-deployer on rlspolicy details
                        SET
                            @sql_stmt
                            = N'REVOKE INSERT ON [mgmt_xtinfra].[infra_orders_details_rlspolicy] FROM '
                            + QUOTENAME(@deployer_role_name)
                            + ';'
                        EXEC [sp_executesql] @sql_stmt;

                    END
                ELSE IF @mode = 'validate'
                    BEGIN
                        PRINT 'Running migration in validate mode: ' + @proc_name;

                        --- validate rls policy management SP
                        IF
                            OBJECT_ID(@sp_workspace_rlspolicy_order_create_or_update_name, 'P'
                            ) IS NULL
                            THROW 50000, 'Rls policy management SP does not exist.', 1;

                        IF OBJECT_ID(@sp_workspace_rlspolicy_order_delete_name, 'P') IS NULL
                            THROW 50000, 'Rls policy management SP does not exist.', 1;

                        --- validate permissions
                        IF
                            HAS_PERMS_BY_NAME(
                                @mgmt_sp_infra_rlspolicy_order_create_or_update,
                                'OBJECT',
                                'EXECUTE'
                            )
                            = 0
                            THROW 50000,
                            'Role does not have EXECUTE permission on [mgmt_xtinfra].[sp_infra_rlspolicy_order_create].',
                            1;
                        IF
                            HAS_PERMS_BY_NAME(
                                @mgmt_sp_infra_rlspolicy_order_delete,
                                'OBJECT',
                                'EXECUTE'
                            )
                            = 0
                            THROW 50000,
                            'Role does not have EXECUTE permission on [mgmt_xtinfra].[sp_infra_rlspolicy_order_delete].',
                            1;
                        IF
                            HAS_PERMS_BY_NAME(
                                '[mgmt_xtinfra].[sp_infra_job_log_execution]',
                                'OBJECT',
                                'EXECUTE'
                            )
                            = 0
                            THROW 50000,
                            'Role does not have EXECUTE permission on [mgmt_xtinfra].[sp_infra_job_log_execution].',
                            1;
                        IF
                            HAS_PERMS_BY_NAME(
                                '[mgmt_xtinfra].[sp_infra_job_log_execution_details]',
                                'OBJECT',
                                'EXECUTE'
                            )
                            = 0
                            THROW 50000,
                            'Role does not have EXECUTE permission on [mgmt_xtinfra].[sp_infra_job_log_execution_details].',
                            1;

                        --- rlspolicy order details table
                        IF HAS_PERMS_BY_NAME('[mgmt_xtinfra].[infra_orders_details_rlspolicy]', 'OBJECT', 'INSERT') = 0
                            THROW 50000,
                            'Role does not have INSERT permission on [mgmt_xtinfra].[infra_orders_details_rlspolicy].',
                            1;

                        --- logging tables
                        IF HAS_PERMS_BY_NAME('[mgmt_xtinfra].[infra_job_master_v2_details]', 'OBJECT', 'INSERT') = 0
                            THROW 50000,
                            'Role does not have INSERT permission on [mgmt_xtinfra].[infra_job_master_v2_details].',
                            1;
                        IF HAS_PERMS_BY_NAME('[mgmt_xtinfra].[infra_job_master_v2]', 'OBJECT', 'INSERT') = 0
                            THROW 50000,
                            'Role does not have INSERT permission on [mgmt_xtinfra].[infra_job_master_v2].',
                            1;
                    END
                ELSE
                    THROW 50000, 'Invalid mode specified for migration task.', 1;

                --- persist object version
                EXEC [mgmt_xtinfra].[sp_infra_set_object_version]
                    @version_object_type, @version_object_name, @version_object_version
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

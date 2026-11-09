/*
Description:
Adds necessary permissions to schema-deployer for schedule and underlying objects.
Adds views for infra_schedule and expanded_schedule in the @workspace_name schema.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workspace_migrationtask_0006] (
    @mode [nvarchar](32),
    @workspace_name [nvarchar](10)
) AS
BEGIN
    ---------------------------------------
    --- TASK INITIALIZATION STARTS HERE ---
    ---------------------------------------

    DECLARE @proc_name nvarchar(128) = 'sp_infra_workspace_migrationtask_0006';

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
            @mgmt_sp_infra_schedule_create_name nvarchar(128) = '[mgmt_xtinfra].[sp_infra_schedule_create]';
        DECLARE
           @sp_workspace_schedule_delete_name nvarchar(128) = QUOTENAME(@workspace_name) + '.[sp_workspace_schedule_delete]';
        DECLARE
            @sp_workspace_schedule_create_name nvarchar(128) = QUOTENAME(@workspace_name) + '.[sp_workspace_schedule_create]';
        DECLARE @mgmt_sp_infra_schedule_delete_name nvarchar(128) = '[mgmt_xtinfra].[sp_infra_schedule_delete]';
        DECLARE @mgmt_InfraValidateCrontabMonth nvarchar(128) = '[mgmt_xtinfra].[InfraValidateCrontabMonth]';
        DECLARE @mgmt_InfraValidateCrontabDayOfWeek nvarchar(128) = '[mgmt_xtinfra].[InfraValidateCrontabDayOfWeek]';
        DECLARE @mgmt_InfraValidateCrontabDayOfMonth nvarchar(128) = '[mgmt_xtinfra].[InfraValidateCrontabDayOfMonth]';
        DECLARE @view_workspace_schedule nvarchar(128) = QUOTENAME(@workspace_name) + '.[v_schedule]';
        DECLARE @view_workspace_expanded_schedule nvarchar(128) = QUOTENAME(@workspace_name) + '.[v_expanded_schedule]';
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

                    SET @sql_stmt = N'GRANT DELETE,INSERT ON [mgmt_xtinfra].[infra_schedule] TO ' + @deployer_role_name + ';'
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @mgmt_InfraValidateCrontabDayOfMonth
                        + ' TO '
                        + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @mgmt_InfraValidateCrontabDayOfWeek
                        + ' TO '
                        + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @mgmt_InfraValidateCrontabMonth
                        + ' TO '
                        + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    IF OBJECT_ID(@view_workspace_schedule, 'V') IS NULL
                        BEGIN
                            SET
                                @sql_stmt = N'CREATE VIEW '
                                + @view_workspace_schedule
                                + ' AS SELECT
                                    [key],
                                    [hour],
                                    [day_of_month],
                                    [month],
                                    [day_of_week],
                                    [schedule_action],
                                    [priority],
                                    [created_at]
                                    FROM [mgmt_xtinfra].[infra_schedule];'
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    IF OBJECT_ID(@view_workspace_expanded_schedule, 'V') IS NULL
                        BEGIN
                            SET
                                @sql_stmt = N'CREATE VIEW '
                                + @view_workspace_expanded_schedule
                                + ' AS SELECT
                                    [key],
                                    [schedule_action],
                                    [schedule_time],
                                    [created_at]
                                    FROM [mgmt_xtinfra].[infra_expanded_schedule] WHERE schedule_time >= GETDATE();'
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @mgmt_sp_infra_schedule_delete_name
                        + ' TO ' + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @mgmt_sp_infra_schedule_create_name
                        + ' TO ' + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    IF OBJECT_ID(@sp_workspace_schedule_delete_name, 'P') IS NULL
                        BEGIN
                            SET
                                @sql_stmt = N'CREATE PROCEDURE '
                                + @sp_workspace_schedule_delete_name
                                + ' @key [nvarchar](100) AS '
                                + N'EXEC '
                                + @mgmt_sp_infra_schedule_delete_name
                                + ' @key;'
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    IF OBJECT_ID(@sp_workspace_schedule_create_name, 'P') IS NULL
                        BEGIN
                            SET
                                @sql_stmt = N'CREATE PROCEDURE '
                                + @sp_workspace_schedule_create_name
                                + ' @key [nvarchar](100), '
                                + '@schedule_action [nvarchar](100), '
                                + '@hour [int], '
                                + '@day_of_month [nvarchar](100), '
                                + '@month [nvarchar](100), '
                                + '@day_of_week [nvarchar](100), '
                                + '@priority [int] AS '
                                + N'EXEC '
                                + @mgmt_sp_infra_schedule_create_name
                                + ' @key, '
                                + '@schedule_action, '
                                + '@hour, '
                                + '@day_of_month, '
                                + '@month, '
                                + '@day_of_week, '
                                + '@priority;'
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @sp_workspace_schedule_delete_name
                        + ' TO '
                        + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @sp_workspace_schedule_create_name
                        + ' TO '
                        + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;
                END
            ELSE IF @mode = 'downgrade'
                BEGIN
                    PRINT 'Running migration in downgrade mode: ' + @proc_name;

                    SET @sql_stmt = N'REVOKE DELETE,INSERT ON [mgmt_xtinfra].[infra_schedule] FROM ' + @deployer_role_name + ';'
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt
                        = N'REVOKE EXECUTE ON '
                        + @mgmt_sp_infra_schedule_create_name
                        + ' FROM '
                        + @deployer_role_name
                        + ';'
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt
                        = N'REVOKE EXECUTE ON '
                        + @mgmt_sp_infra_schedule_delete_name
                        + ' FROM '
                        + @deployer_role_name
                        + ';'
                    EXEC [sp_executesql] @sql_stmt;

                    IF OBJECT_ID(@sp_workspace_schedule_delete_name, 'P') IS NOT NULL
                        BEGIN
                            SET
                                @sql_stmt = N'DROP PROCEDURE ' + @sp_workspace_schedule_delete_name;
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    IF OBJECT_ID(@sp_workspace_schedule_create_name, 'P') IS NOT NULL
                        BEGIN
                            SET
                                @sql_stmt = N'DROP PROCEDURE ' + @sp_workspace_schedule_create_name;
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    SET @sql_stmt = N'DROP VIEW IF EXISTS ' + @view_workspace_schedule;
                    EXEC [sp_executesql] @sql_stmt;

                    SET @sql_stmt = N'DROP VIEW IF EXISTS ' + @view_workspace_expanded_schedule;
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'REVOKE EXECUTE ON '
                        + @mgmt_InfraValidateCrontabDayOfMonth
                        + ' FROM '
                        + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'REVOKE EXECUTE ON '
                        + @mgmt_InfraValidateCrontabDayOfWeek
                        + ' FROM '
                        + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'REVOKE EXECUTE ON '
                        + @mgmt_InfraValidateCrontabMonth
                        + ' FROM '
                        + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;
                END
            ELSE IF @mode = 'validate'
                BEGIN
                    PRINT 'Running migration in validate mode: ' + @proc_name;

                    IF
                        OBJECT_ID(@sp_workspace_schedule_delete_name, 'P') IS NULL
                        THROW 50000, '[sp_workspace_schedule_delete] does not exist.', 1;

                    IF
                        OBJECT_ID(@sp_workspace_schedule_create_name, 'P') IS NULL
                        THROW 50000, '[sp_workspace_schedule_create] does not exist.', 1;

                    IF
                        OBJECT_ID(@view_workspace_schedule, 'V') IS NULL
                        THROW 50000, '[v_schedule] does not exist.', 1;

                    IF
                        OBJECT_ID(@view_workspace_expanded_schedule, 'V') IS NULL
                        THROW 50000, '[v_expanded_schedule] does not exist.', 1;

                    --- validate permissions
                    IF
                        HAS_PERMS_BY_NAME(
                            @mgmt_sp_infra_schedule_create_name,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [mgmt_xtinfra].[sp_infra_schedule_create]',
                        1;

                    IF
                        HAS_PERMS_BY_NAME(
                            @mgmt_sp_infra_schedule_delete_name,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [mgmt_xtinfra].[sp_infra_schedule_delete]',
                        1;

                    IF
                        HAS_PERMS_BY_NAME(
                            @sp_workspace_schedule_create_name,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [sp_workspace_schedule_create]',
                        1;

                    IF
                        HAS_PERMS_BY_NAME(
                            @sp_workspace_schedule_delete_name,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [sp_workspace_schedule_delete]',
                        1;

                    IF
                        HAS_PERMS_BY_NAME(
                            @mgmt_InfraValidateCrontabDayOfMonth,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [mgmt_xtinfra].[InfraValidateCrontabDayOfMonth]',
                        1;

                    IF
                        HAS_PERMS_BY_NAME(
                            @mgmt_InfraValidateCrontabDayOfWeek,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [mgmt_xtinfra].[InfraValidateCrontabDayOfWeek]',
                        1;

                    IF
                        HAS_PERMS_BY_NAME(
                            @mgmt_InfraValidateCrontabMonth,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [mgmt_xtinfra].[InfraValidateCrontabMonth]',
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

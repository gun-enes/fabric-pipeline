/*
Description:
Adds necessary permissions to schema-deployer for schedule and underlying objects.
Adds views for infra_schedule and expanded_schedule in the @workspace_name schema.

Author:
jyothish.b@allianz.com
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workspace_migrationtask_0011] (
    @mode [nvarchar](32),
    @workspace_name [nvarchar](10)
) AS
BEGIN
    ---------------------------------------
    --- TASK INITIALIZATION STARTS HERE ---
    ---------------------------------------

    DECLARE @proc_name nvarchar(128) = 'sp_infra_workspace_migrationtask_0011';
    DECLARE @infra_object_type nvarchar(128) = 'workspace';
    DECLARE @infra_object_name nvarchar(256) = @workspace_name;
    DECLARE @log_detail_group uniqueidentifier = NEWID();

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

        DECLARE @sql_stmt nvarchar(1024);
        DECLARE @mgmt_sp_infra_gatherstats_schedule_create_name nvarchar(128) = '[mgmt_xtinfra].[sp_infra_gatherstats_schedule_create]';
        DECLARE @sp_workspace_gatherstats_schedule_delete_name nvarchar(128) = QUOTENAME(@workspace_name) + '.[sp_workspace_gatherstats_schedule_delete]';
        DECLARE @sp_workspace_gatherstats_schedule_create_name nvarchar(128) = QUOTENAME(@workspace_name) + '.[sp_workspace_gatherstats_schedule_create]';
        DECLARE @mgmt_sp_infra_gatherstats_schedule_delete_name nvarchar(128) = '[mgmt_xtinfra].[sp_infra_gatherstats_schedule_delete]';
        DECLARE @view_workspace_expanded_gatherstats_schedule nvarchar(128) = QUOTENAME(@workspace_name) + '.[v_expanded_gatherstats_schedule]';
        DECLARE @deployer_role_name nvarchar(128) = QUOTENAME([mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer'));
        DECLARE @writer_role_name nvarchar(128) = QUOTENAME([mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'writer'));

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

                    SET @sql_stmt = N'GRANT DELETE,INSERT ON [mgmt_xtinfra].[infra_gatherstats_schedule_detail] TO ' + @deployer_role_name + ';'
                    EXEC [sp_executesql] @sql_stmt;

                    IF OBJECT_ID(@view_workspace_expanded_gatherstats_schedule, 'V') IS NULL
                        BEGIN
                            SET
                                @sql_stmt = N'CREATE VIEW '
                                + @view_workspace_expanded_gatherstats_schedule
                                + ' AS SELECT
                                    A.[key],
                                    A.[schedule_action],
                                    A.[schedule_time],
                                    A.[created_at],
                                    B.[stats_type],
                                    B.[stats_pct],
                                    B.[schema_name]
                                    FROM [mgmt_xtinfra].[infra_expanded_schedule] A,
                                    [mgmt_xtinfra].[infra_gatherstats_schedule_detail] B WHERE A.[key] = B.[infra_schedule_key]
                                    AND A.[schedule_time] >= GETDATE();'
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    SET
                        @sql_stmt = N'GRANT SELECT ON '
                        + @view_workspace_expanded_gatherstats_schedule
                        + ' TO ' + @writer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @mgmt_sp_infra_gatherstats_schedule_delete_name
                        + ' TO ' + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @mgmt_sp_infra_gatherstats_schedule_create_name
                        + ' TO ' + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    IF OBJECT_ID(@sp_workspace_gatherstats_schedule_delete_name, 'P') IS NULL
                        BEGIN
                            SET
                                @sql_stmt = N'CREATE PROCEDURE '
                                + @sp_workspace_gatherstats_schedule_delete_name
                                + ' @key [nvarchar](100) AS '
                                + N'EXEC '
                                + @mgmt_sp_infra_gatherstats_schedule_delete_name
                                + ' @key,'
                                + QUOTENAME(@workspace_name, '''');
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    IF OBJECT_ID(@sp_workspace_gatherstats_schedule_create_name, 'P') IS NULL
                        BEGIN
                            SET
                                @sql_stmt = N'CREATE PROCEDURE '
                                + @sp_workspace_gatherstats_schedule_create_name
                                + ' @key [nvarchar](100), '
                                + '@hour [int], '
                                + '@day_of_month [nvarchar](100), '
                                + '@month [nvarchar](100), '
                                + '@day_of_week [nvarchar](100), '
                                + '@priority [int], '
                                + '@stats_type [NVARCHAR](6), '
                                + '@stats_pct [int], '
                                + '@schema_name [NVARCHAR](43) AS '
                                + N'EXEC '
                                + @mgmt_sp_infra_gatherstats_schedule_create_name
                                + ' @key, '
                                + '@hour, '
                                + '@day_of_month, '
                                + '@month, '
                                + '@day_of_week, '
                                + '@priority, '
                                + QUOTENAME(@workspace_name, '''')
                                + ', @stats_type, '
                                + '@stats_pct, '
                                + '@schema_name;'
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @sp_workspace_gatherstats_schedule_delete_name
                        + ' TO '
                        + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @sp_workspace_gatherstats_schedule_create_name
                        + ' TO '
                        + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;
                END
            ELSE IF @mode = 'downgrade'
                BEGIN
                    PRINT 'Running migration in downgrade mode: ' + @proc_name;

                    SET
                        @sql_stmt
                        = N'REVOKE EXECUTE ON '
                        + @mgmt_sp_infra_gatherstats_schedule_create_name
                        + ' FROM '
                        + @deployer_role_name
                        + ';'
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt
                        = N'REVOKE EXECUTE ON '
                        + @mgmt_sp_infra_gatherstats_schedule_delete_name
                        + ' FROM '
                        + @deployer_role_name
                        + ';'
                    EXEC [sp_executesql] @sql_stmt;

                    IF OBJECT_ID(@sp_workspace_gatherstats_schedule_delete_name, 'P') IS NOT NULL
                        BEGIN
                            SET
                                @sql_stmt = N'DROP PROCEDURE ' + @sp_workspace_gatherstats_schedule_delete_name;
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    IF OBJECT_ID(@sp_workspace_gatherstats_schedule_create_name, 'P') IS NOT NULL
                        BEGIN
                            SET
                                @sql_stmt = N'DROP PROCEDURE ' + @sp_workspace_gatherstats_schedule_create_name;
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    SET @sql_stmt = N'DROP VIEW IF EXISTS ' + @view_workspace_expanded_gatherstats_schedule;
                    EXEC [sp_executesql] @sql_stmt;
                END
            ELSE IF @mode = 'validate'
                BEGIN
                    PRINT 'Running migration in validate mode: ' + @proc_name;

                    IF
                        OBJECT_ID(@sp_workspace_gatherstats_schedule_delete_name, 'P') IS NULL
                        THROW 50000, '[sp_workspace_gatherstats_schedule_delete] does not exist.', 1;

                    IF
                        OBJECT_ID(@sp_workspace_gatherstats_schedule_create_name, 'P') IS NULL
                        THROW 50000, '[sp_workspace_gatherstats_schedule_create] does not exist.', 1;

                    IF
                        OBJECT_ID(@view_workspace_expanded_gatherstats_schedule, 'V') IS NULL
                        THROW 50000, '[v_expanded_gatherstats_schedule] does not exist.', 1;

                    --- validate permissions
                    IF
                        HAS_PERMS_BY_NAME(
                            @mgmt_sp_infra_gatherstats_schedule_create_name,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [mgmt_xtinfra].[sp_infra_gatherstats_schedule_create]',
                        1;

                    IF
                        HAS_PERMS_BY_NAME(
                            @mgmt_sp_infra_gatherstats_schedule_delete_name,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [mgmt_xtinfra].[sp_infra_gatherstats_schedule_delete]',
                        1;

                    IF
                        HAS_PERMS_BY_NAME(
                            @sp_workspace_gatherstats_schedule_create_name,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [sp_workspace_gatherstats_schedule_create]',
                        1;

                    IF
                        HAS_PERMS_BY_NAME(
                            @sp_workspace_gatherstats_schedule_delete_name,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [sp_workspace_gatherstats_schedule_delete]',
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

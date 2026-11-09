/*
Description:


Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workspace_migrationtask_0012] (
    @mode [nvarchar](32),
    @workspace_name [nvarchar](10)
) AS
BEGIN
    ---------------------------------------
    --- TASK INITIALIZATION STARTS HERE ---
    ---------------------------------------

    DECLARE @proc_name nvarchar(128) = 'sp_infra_workspace_migrationtask_0012';
    DECLARE @infra_object_type nvarchar(128) = 'workspace';
    DECLARE @infra_object_name nvarchar(256) = @workspace_name;
    DECLARE @log_detail_group uniqueidentifier = NEWID();

    BEGIN TRY

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workspace_name', @workspace_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;

        -- on downgrades we will set the target version to the previous version
        DECLARE @migrationtask_id int = [mgmt_xtinfra].InfraGetMigrationTaskId(@proc_name);
        DECLARE @infra_object_version int = @migrationtask_id;

        IF @mode = 'downgrade'
            SET @infra_object_version = @migrationtask_id - 1

        DECLARE @sql_stmt nvarchar(MAX);
        DECLARE @mgmt_sp_infra_set_config_setting_name nvarchar(128) = '[mgmt_xtinfra].[sp_infra_set_config_setting]';
        DECLARE @sp_workspace_set_config_setting_name nvarchar(128) = QUOTENAME(@workspace_name) + '.[sp_workspace_set_config_setting]';
        DECLARE @view_infra_config_settings nvarchar(128) = QUOTENAME(@workspace_name) + '.[v_infra_config_settings]';
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

                    SET @sql_stmt = N'GRANT UPDATE,INSERT ON [mgmt_xtinfra].[infra_config_settings] TO ' + @deployer_role_name + ';'
                    EXEC [sp_executesql] @sql_stmt;

                    IF OBJECT_ID(@view_infra_config_settings, 'V') IS NULL
                    BEGIN
                        SET @sql_stmt = N'CREATE VIEW ' + @view_infra_config_settings + N'
                            AS
                            WITH expected_settings AS (
                                SELECT
                                    wic.workspace_name,
                                    wic.synapse_workspace_msi_name,
                                    cfg.name,
                                    ''disabled'' AS default_value
                                FROM mgmt_xtinfra.infra_workspace_identity_config AS wic
                                CROSS JOIN (
                                    SELECT ''on-pause-pipeline-wait-opt-out'' AS name
                                    UNION ALL
                                    SELECT ''opt-in-for-ms-maintenance''
                                ) AS cfg
                            )
                            SELECT
                                es.workspace_name,
                                es.synapse_workspace_msi_name AS synapse_workspace,
                                es.name,
                                ISNULL(cs.value, es.default_value) AS value,
                                ISNULL(cs.created_at, GETUTCDATE()) AS created_at,
                                ISNULL(cs.modified_at, GETUTCDATE()) AS modified_at,
                                cs.requestor
                            FROM expected_settings AS es
                            LEFT JOIN mgmt_xtinfra.infra_config_settings AS cs
                                ON es.workspace_name = cs.workspace_name
                            AND es.name = cs.name;
                            ';
                        EXEC [sp_executesql] @sql_stmt;
                    END

                    SET
                        @sql_stmt = N'GRANT SELECT ON '
                        + @view_infra_config_settings
                        + ' TO ' + @writer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt = N'GRANT EXECUTE ON '
                        + @mgmt_sp_infra_set_config_setting_name
                        + ' TO ' + @deployer_role_name + ';';
                    EXEC [sp_executesql] @sql_stmt;

                    IF OBJECT_ID(@sp_workspace_set_config_setting_name, 'P') IS NULL
                        BEGIN
                            SET
                                @sql_stmt = N'CREATE PROCEDURE '
                                + @sp_workspace_set_config_setting_name
                                + ' @config_workspace_name [nvarchar](10), '
                                + '@name [nvarchar](128), '
                                + '@value [nvarchar](128) AS '
                                + N'EXEC '
                                + @mgmt_sp_infra_set_config_setting_name
                                + ' @config_workspace_name, '
                                + '@name, '
                                + '@value, '
                                + QUOTENAME(@workspace_name, '''')
                                + ';'
                            EXEC [sp_executesql] @sql_stmt;
                        END
                END
            ELSE IF @mode = 'downgrade'
                BEGIN
                    PRINT 'Running migration in downgrade mode: ' + @proc_name;

                    SET @sql_stmt = N'REVOKE UPDATE,INSERT ON [mgmt_xtinfra].[infra_config_settings] FROM ' + @deployer_role_name + ';'
                    EXEC [sp_executesql] @sql_stmt;

                    SET
                        @sql_stmt
                        = N'REVOKE EXECUTE ON '
                        + @mgmt_sp_infra_set_config_setting_name
                        + ' FROM '
                        + @deployer_role_name
                        + ';'
                    EXEC [sp_executesql] @sql_stmt;

                    IF OBJECT_ID(@sp_workspace_set_config_setting_name, 'P') IS NOT NULL
                        BEGIN
                            SET
                                @sql_stmt = N'DROP PROCEDURE ' + @sp_workspace_set_config_setting_name;
                            EXEC [sp_executesql] @sql_stmt;
                        END

                    SET @sql_stmt = N'DROP VIEW IF EXISTS ' + @view_infra_config_settings;
                    EXEC [sp_executesql] @sql_stmt;
                END
            ELSE IF @mode = 'validate'
                BEGIN
                    PRINT 'Running migration in validate mode: ' + @proc_name;

                    IF
                        OBJECT_ID(@sp_workspace_set_config_setting_name, 'P') IS NULL
                        THROW 50000, '[sp_workspace_set_config_setting] does not exist.', 1;

                    IF
                        OBJECT_ID(@view_infra_config_settings, 'V') IS NULL
                        THROW 50000, '[v_opt_out_mode] does not exist.', 1;

                    --- validate permissions
                    IF
                        HAS_PERMS_BY_NAME(
                            @mgmt_sp_infra_set_config_setting_name,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [mgmt_xtinfra].[sp_infra_set_config_setting]',
                        1;

                    IF
                        HAS_PERMS_BY_NAME(
                            @sp_workspace_set_config_setting_name,
                            'OBJECT',
                            'EXECUTE'
                        ) = 0
                        THROW 50000,
                        'Role does not have EXECUTE permission on [sp_workspace_set_config_setting]',
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

BEGIN
    DECLARE @mgmt_admin_group_name AS NVARCHAR(100);
    DECLARE @mgmt_operations_group_name AS NVARCHAR(100);
    DECLARE @mgmt_contributor_group_name AS NVARCHAR(100);
    DECLARE @mgmt_reader_group_name AS NVARCHAR(100);
    DECLARE @mgmt_synapse_workspace_msi_name AS NVARCHAR(100);
    DECLARE @mgmt_service_principal_name AS NVARCHAR(100);
    DECLARE @mgmt_service_principal_name_tf_plan AS NVARCHAR(100);
    DECLARE @mgmt_reporting_group_name AS NVARCHAR(100);
    DECLARE @mgmt_appName AS NVARCHAR(100);
    DECLARE @mgmt_appWorkspace AS NVARCHAR(100);

    -- MGMT
    PRINT ('[MGMT] Management Role Assignment Execution')

    --set variables
    SELECT
        @mgmt_appName = [workspace_name],
        @mgmt_appWorkspace = [workspace_name],
        @mgmt_admin_group_name = [admin_group_name],
        @mgmt_operations_group_name = [operations_group_name],
        @mgmt_contributor_group_name = [contributor_group_name],
        @mgmt_reader_group_name = [reader_group_name],
        @mgmt_synapse_workspace_msi_name = [synapse_workspace_msi_name],
        @mgmt_service_principal_name = [service_principal_name],
        @mgmt_service_principal_name_tf_plan = [service_principal_name_tf_plan]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'management';

    --create users
    PRINT ('[MGMT] Started creating identity users')
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @mgmt_admin_group_name, @mgmt_appWorkspace, @mgmt_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @mgmt_operations_group_name, @mgmt_appWorkspace, @mgmt_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @mgmt_contributor_group_name, @mgmt_appWorkspace, @mgmt_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @mgmt_reader_group_name, @mgmt_appWorkspace, @mgmt_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @mgmt_synapse_workspace_msi_name, @mgmt_appWorkspace, @mgmt_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @mgmt_service_principal_name, @mgmt_appWorkspace, @mgmt_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @mgmt_service_principal_name_tf_plan, @mgmt_appWorkspace, @mgmt_appName;

    --create reporting group users
    SELECT
        @cmd = STRING_AGG(
            CAST(
                CONCAT(
                    'EXEC [mgmt_xtinfra].[sp_infra_add_user] ',
                    QUOTENAME([reporting_group_name], ''''), ', ',
                    QUOTENAME(@mgmt_appWorkspace, ''''), ', ',
                    QUOTENAME(@mgmt_appName, '''')
                ) AS NVARCHAR(MAX)
            ),
            CHAR(10)
        )
    FROM [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
    WHERE [workspace_type] = 'management'
    EXEC (@cmd);
    PRINT ('[MGMT] Finished creating identity users');

    PRINT ('[MGMT] Started assigning roles to identity users');
    IF (@mgmt_operations_group_name <> '#')
        BEGIN
            PRINT ('[MGMT] Operations group name: ' + @mgmt_operations_group_name);
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                'db_backupoperator', @mgmt_operations_group_name, 'generic', @mgmt_appWorkspace, @mgmt_appName;
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                'db_ddladmin', @mgmt_operations_group_name, 'generic', @mgmt_appWorkspace, @mgmt_appName;
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                'db_datawriter', @mgmt_operations_group_name, 'generic', @mgmt_appWorkspace, @mgmt_appName;
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                'db_datareader', @mgmt_operations_group_name, 'generic', @mgmt_appWorkspace, @mgmt_appName;
        END

    IF (@mgmt_contributor_group_name <> '#')
        BEGIN
            PRINT ('[MGMT] Contributor group name : ' + @mgmt_contributor_group_name);
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                'db_datawriter', @mgmt_contributor_group_name, 'generic', @mgmt_appWorkspace, @mgmt_appName;
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                'db_ddladmin', @mgmt_contributor_group_name, 'generic', @mgmt_appWorkspace, @mgmt_appName;
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                'db_datareader', @mgmt_contributor_group_name, 'generic', @mgmt_appWorkspace, @mgmt_appName;
        END

    IF (@mgmt_service_principal_name_tf_plan <> '#')
        BEGIN
            PRINT ('[MGMT] Service Principal for TF plan : ' + @mgmt_service_principal_name_tf_plan);
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                'db_datareader', @mgmt_service_principal_name_tf_plan, 'generic', @mgmt_appWorkspace, @mgmt_appName;
        END

    IF (@mgmt_reader_group_name <> '#')
        BEGIN
            PRINT ('[MGMT] Reader group name: ' + @mgmt_reader_group_name);
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                'db_datareader', @mgmt_reader_group_name, 'generic', @mgmt_appWorkspace, @mgmt_appName;
        END
    PRINT ('[MGMT] Finished assigning roles to identity users');
END

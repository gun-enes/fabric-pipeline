BEGIN
    DECLARE @core_admin_group_name AS NVARCHAR(100);
    DECLARE @core_operations_group_name AS NVARCHAR(100);
    DECLARE @core_contributor_group_name AS NVARCHAR(100);
    DECLARE @core_reader_group_name AS NVARCHAR(100);
    DECLARE @core_synapse_workspace_msi_name AS NVARCHAR(100);
    DECLARE @core_service_principal_name AS NVARCHAR(100);
    DECLARE @core_reporting_group_name AS NVARCHAR(100);
    DECLARE @core_actions_group_name AS NVARCHAR(100);
    DECLARE @core_appName AS NVARCHAR(100);
    DECLARE @core_appWorkspace AS NVARCHAR(100);

    -- CORE
    PRINT ('[CORE] Core Role Assignment Execution')

    --set variables
    SELECT
        @core_appName = [workspace_name],
        @core_appWorkspace = [workspace_name],
        @core_admin_group_name = [admin_group_name],
        @core_operations_group_name = [operations_group_name],
        @core_contributor_group_name = [contributor_group_name],
        @core_reader_group_name = [reader_group_name],
        @core_synapse_workspace_msi_name = [synapse_workspace_msi_name],
        @core_service_principal_name = [service_principal_name],
        @core_actions_group_name = [actions_group_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core';

    --create users
    PRINT ('[CORE] Started creating identity users')
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @core_admin_group_name, @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @core_operations_group_name, @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @core_contributor_group_name, @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @core_reader_group_name, @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @core_synapse_workspace_msi_name, @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @core_service_principal_name, @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @core_actions_group_name, @core_appWorkspace, @core_appName;

    --create reporting group users
    SELECT
        @cmd = STRING_AGG(
            CAST(
                CONCAT(
                    'EXEC [mgmt_xtinfra].[sp_infra_add_user] ',
                    QUOTENAME([reporting_group_name], ''''), ', ',
                    QUOTENAME(@core_appWorkspace, ''''), ', ',
                    QUOTENAME(@core_appName, '''')
                ) AS NVARCHAR(MAX)
            ),
            CHAR(10)
        )
    FROM [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
    WHERE [workspace_type] = 'core'
    EXEC (@cmd)
    PRINT ('[CORE] Finished creating identity users')

    PRINT ('[CORE] Started assigning roles to identity users')
    --Global roles for synapse_workspace_msi_name
    PRINT ('Adding global roles for Synapse workspace msi');
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ViewDatabaseState', @core_synapse_workspace_msi_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AdministerDatabaseBulkOperations', @core_synapse_workspace_msi_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AlterAnyDataspace', @core_synapse_workspace_msi_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SparkConnector', @core_synapse_workspace_msi_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_CriticalGroupClassifier', @core_synapse_workspace_msi_name, 'generic', @core_appWorkspace, @core_appName;

    -- additional roles for actions group
    PRINT ('Adding global roles for actions group');
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ExternalDataCreator', @core_actions_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ActionsExecutor', @core_actions_group_name, 'generic', @core_appWorkspace, @core_appName;

    -- additional roles for service principal name (deploy)
    PRINT ('Adding global roles for service principal');
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SchemaDeployer', @core_service_principal_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AlterAnyDataspace', @core_service_principal_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ExternalDataCreator', @core_service_principal_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AdhocGroupClassifier', @core_service_principal_name, 'generic', @core_appWorkspace, @core_appName;

    -- additional roles for operations group
    PRINT ('Adding global roles for operations group');
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_OtherGroupClassifier', @core_operations_group_name, 'generic', @core_appWorkspace, @core_appName;

    -- additional roles for reader group
    PRINT ('Adding global roles for reader group');
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_RepoGroupClassifier', @core_reader_group_name, 'generic', @core_appWorkspace, @core_appName;

    -- additional roles for reporting groups
    PRINT ('Adding global roles for reporting groups');
    SELECT
        @cmd = STRING_AGG(
            CAST(
                CONCAT(
                    'EXEC [mgmt_xtinfra].[sp_infra_login_sync_role] ''Role_RepoGroupClassifier'', ',
                    QUOTENAME([reporting_group_name], ''''),
                    ', ''generic'', ',
                    QUOTENAME(@core_appWorkspace, ''''),
                    ', ',
                    QUOTENAME(@core_appName, '''')
                ) AS NVARCHAR(MAX)
            ),
            CHAR(10)
        )
    FROM [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
    WHERE [workspace_type] = 'core'

    PRINT(@cmd);
    EXEC (@cmd);

    -- and for contributor & admin
    PRINT ('Adding global roles for admin and contributor');
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SHOWPLAN', @core_contributor_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SHOWPLAN', @core_admin_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_VIEWDEFINITION', @core_contributor_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_VIEWDEFINITION', @core_admin_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ExternalDataCreator', @core_contributor_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ExternalDataCreator', @core_admin_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AlterAnyDataspace', @core_contributor_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AlterAnyDataspace', @core_admin_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ViewDatabaseState', @core_contributor_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ViewDatabaseState', @core_admin_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SparkConnector', @core_contributor_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SparkConnector', @core_admin_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AdhocGroupClassifier', @core_contributor_group_name, 'generic', @core_appWorkspace, @core_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_OtherGroupClassifier', @core_admin_group_name, 'generic', @core_appWorkspace, @core_appName;


    PRINT ('[CORE] Assigning Core users roles on Core workspace')
    IF (@core_admin_group_name <> '#')
        BEGIN
            PRINT (
                '[CORE] Admin group Name: ' + @core_admin_group_name + ' for ' + @core_appWorkspace
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @core_appWorkspace, @core_admin_group_name, 'writer', @core_appWorkspace, @core_appName;
        END
    IF (@core_operations_group_name <> '#')
        BEGIN
            PRINT (
                '[CORE] Operations group name: '
                + @core_operations_group_name
                + ' for '
                + @core_appWorkspace
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @core_appWorkspace, @core_operations_group_name, 'writer', @core_appWorkspace, @core_appName;
        END
    IF (@core_contributor_group_name <> '#')
        BEGIN
            PRINT (
                '[CORE] Contributor group name : '
                + @core_operations_group_name
                + ' for '
                + @core_appWorkspace
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @core_appWorkspace, @core_contributor_group_name, 'writer', @core_appWorkspace, @core_appName;
        END
    IF (@core_reader_group_name <> '#')
        BEGIN
            PRINT (
                '[CORE] Reader group name: '
                + @core_reader_group_name
                + ' for '
                + @core_appWorkspace
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @core_appWorkspace, @core_reader_group_name, 'reader', @core_appWorkspace, @core_appName;
        END
    IF (@core_synapse_workspace_msi_name <> '#')
        BEGIN
            PRINT (
                '[CORE] Synapse workspace msi name: '
                + @core_synapse_workspace_msi_name
                + ' for '
                + @core_appWorkspace
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @core_appWorkspace, @core_synapse_workspace_msi_name, 'writer', @core_appWorkspace, @core_appName;
        END
    IF (@core_service_principal_name <> '#')
        BEGIN
            PRINT (
                '[CORE] Service principal name : '
                + @core_service_principal_name
                + ' for '
                + @core_appWorkspace
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @core_appWorkspace, @core_service_principal_name, 'schema_deployer', @core_appWorkspace, @core_appName;
        END

    PRINT ('[CORE] Assigning Core users roles on Extension workspaces')
    SET @extsCounter = 1;
    SET @extsTotal = (
        SELECT COUNT(*)
        FROM [mgmt_xtinfra].[infra_workspace_identity_config]
        WHERE [workspace_type] = 'extension'
    );
    WHILE @extsCounter <= @extsTotal
        BEGIN
            --set variables
            SET @ext_name = (
                SELECT [workspace_name]
                FROM [mgmt_xtinfra].[infra_workspace_identity_config]
                WHERE [workspace_type] = 'extension' AND [type_index] = @extsCounter
            );
            PRINT ('[EXT] Considering extension: ' + @ext_name);
            IF (@core_admin_group_name <> '#')
                BEGIN
                    PRINT (
                        '[CORE] Admin group Name: ' + @core_admin_group_name + ' for: ' + @ext_name
                    );
                    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                        @ext_name, @core_admin_group_name, 'reader', @core_appWorkspace, @core_appName;
                END
            IF (@core_operations_group_name <> '#')
                BEGIN
                    PRINT (
                        '[CORE] Operations group name: '
                        + @core_operations_group_name
                        + ' for: '
                        + @ext_name
                    );
                    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                        @ext_name, @core_operations_group_name, 'reader', @core_appWorkspace, @core_appName;
                END
            IF (@core_contributor_group_name <> '#')
                BEGIN
                    PRINT (
                        '[CORE] Contributor group name : '
                        + @core_contributor_group_name
                        + ' for: '
                        + @ext_name
                    );
                    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                        @ext_name, @core_contributor_group_name, 'reader', @core_appWorkspace, @core_appName;
                END
            IF (@core_synapse_workspace_msi_name <> '#')
                BEGIN
                    PRINT (
                        '[CORE] Synapse workspace msi name: '
                        + @core_synapse_workspace_msi_name
                        + ' for: '
                        + @ext_name
                    );
                    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                        @ext_name, @core_synapse_workspace_msi_name, 'reader', @core_appWorkspace, @core_appName;
                END
            SET @extsCounter = @extsCounter + 1;
        END
    PRINT ('[CORE] Finished assigning roles to identity users')
END

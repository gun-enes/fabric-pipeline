CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_ext_user_role_assignments]
(
    @ext_name NVARCHAR(100)
)
AS
BEGIN
    DECLARE @cmd NVARCHAR(MAX);
    DECLARE @ext_appName AS NVARCHAR(100);
    DECLARE @ext_appWorkspace AS NVARCHAR(100);
    DECLARE @ext_admin_group_name AS NVARCHAR(100);
    DECLARE @ext_operations_group_name AS NVARCHAR(100);
    DECLARE @ext_contributor_group_name AS NVARCHAR(100);
    DECLARE @ext_reader_group_name AS NVARCHAR(100);
    DECLARE @ext_synapse_workspace_msi_name AS NVARCHAR(100);
    DECLARE @ext_service_principal_name AS NVARCHAR(100);
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @proc_name nvarchar(128) = 'sp_infra_ext_user_role_assignments';

    DECLARE @core_workspace_name NVARCHAR(100);

  BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workspace_name', @ext_name;
    SELECT
        @ext_appName = [workspace_name],
        @ext_appWorkspace = [workspace_name],
        @ext_admin_group_name = [admin_group_name],
        @ext_operations_group_name = [operations_group_name],
        @ext_contributor_group_name = [contributor_group_name],
        @ext_reader_group_name = [reader_group_name],
        @ext_synapse_workspace_msi_name = [synapse_workspace_msi_name],
        @ext_service_principal_name = [service_principal_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_name] = @ext_name;

    --create users
    PRINT ('[EXT] Started creating identity users for the extension: ' + @ext_name);

    EXEC [mgmt_xtinfra].[sp_infra_add_user] @ext_admin_group_name, @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @ext_operations_group_name, @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @ext_contributor_group_name, @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @ext_reader_group_name, @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @ext_synapse_workspace_msi_name, @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_add_user] @ext_service_principal_name, @ext_appWorkspace, @ext_appName;

    --create reporting group users
    SET
        @cmd = (SELECT
            STRING_AGG(
                CAST(
                    CONCAT(
                        'EXEC [mgmt_xtinfra].[sp_infra_add_user] ',
                        QUOTENAME([reporting_group_name], ''''), ', ',
                        QUOTENAME(@ext_appWorkspace, ''''), ', ',
                        QUOTENAME(@ext_appName, '''')
                    ) AS NVARCHAR(MAX)
                ),
                CHAR(10)
            )
        FROM [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
        WHERE [workspace_name] = @ext_name)
    EXEC (@cmd);
    PRINT ('[EXT] Finished creating identity users for the extension: ' + @ext_name);

    PRINT ('[EXT] Started assigning roles to identity users for the extension: ' + @ext_name);

    --additional roles for synapse_workspace_msi_name
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ViewDatabaseState', @ext_synapse_workspace_msi_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AdministerDatabaseBulkOperations', @ext_synapse_workspace_msi_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AlterAnyDataspace', @ext_synapse_workspace_msi_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SparkConnector', @ext_synapse_workspace_msi_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_CriticalGroupClassifier', @ext_synapse_workspace_msi_name, 'generic', @ext_appWorkspace, @ext_appName;

    -- additional roles for service principal name (deploy)
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SchemaDeployer', @ext_service_principal_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AlterAnyDataspace', @ext_service_principal_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ExternalDataCreator', @ext_service_principal_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AdhocGroupClassifier', @ext_service_principal_name, 'generic', @ext_appWorkspace, @ext_appName;

    -- additional roles for reader
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AdhocGroupClassifier', @ext_reader_group_name, 'generic', @ext_appWorkspace, @ext_appName;

    -- additional roles for operations group
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_OtherGroupClassifier', @ext_operations_group_name, 'generic', @ext_appWorkspace, @ext_appName;

    -- additional roles for reporting group
    SET
        @cmd
        = (SELECT
            STRING_AGG(
                CAST(
                    CONCAT(
                        'EXEC [mgmt_xtinfra].[sp_infra_login_sync_role] ''',
                        'Role_RepoGroupClassifier'', ',
                        QUOTENAME([reporting_group_name], ''''),
                        ', ''generic'', ',
                        QUOTENAME(@ext_appWorkspace, ''''),
                        ', ',
                        QUOTENAME(@ext_appName, '''')
                    ) AS NVARCHAR(MAX)
                ),
                CHAR(10)
            )
        FROM [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
        WHERE [workspace_name] = @ext_name)

    PRINT(@cmd);
    EXEC (@cmd);

    -- and for contributor & admin
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SHOWPLAN', @ext_contributor_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SHOWPLAN', @ext_admin_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_VIEWDEFINITION', @ext_contributor_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_VIEWDEFINITION', @ext_admin_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ExternalDataCreator', @ext_contributor_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ExternalDataCreator', @ext_admin_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AlterAnyDataspace', @ext_contributor_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AlterAnyDataspace', @ext_admin_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SparkConnector', @ext_contributor_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_SparkConnector', @ext_admin_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    -- added 2024-03-25 as it was missing
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ViewDatabaseState', @ext_contributor_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_ViewDatabaseState', @ext_admin_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'mgmt_xtinfra-schema-reader', @ext_contributor_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_AdhocGroupClassifier', @ext_contributor_group_name, 'generic', @ext_appWorkspace, @ext_appName;
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'Role_OtherGroupClassifier', @ext_admin_group_name, 'generic', @ext_appWorkspace, @ext_appName;

    PRINT ('[EXT] Assigning Extension users roles on Core workspace for extension: ' + @ext_name)

    SELECT @core_workspace_name = [workspace_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core'

    -- ROLES ON CORE WORKSPACE
    PRINT ('[EXT] Considering Core workspace ' + @core_workspace_name);
    IF (@ext_admin_group_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Admin group Name: '
                + @ext_admin_group_name
                + ' adding as reader to: '
                + @core_workspace_name
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @core_workspace_name, @ext_admin_group_name, 'reader', @ext_appWorkspace, @ext_appName;
        END
    IF (@ext_operations_group_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Operations group name: '
                + @ext_operations_group_name
                + ' adding as reader to: '
                + @core_workspace_name
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @core_workspace_name, @ext_operations_group_name, 'reader', @ext_appWorkspace, @ext_appName;
        END
    IF (@ext_contributor_group_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Contributor group name : '
                + @ext_contributor_group_name
                + ' adding as reader to: '
                + @core_workspace_name
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @core_workspace_name, @ext_contributor_group_name, 'reader', @ext_appWorkspace, @ext_appName;
        END
    IF (@ext_synapse_workspace_msi_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Synapse workspace msi name: '
                + @ext_synapse_workspace_msi_name
                + ' adding as reader to: '
                + @core_workspace_name
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @core_workspace_name, @ext_synapse_workspace_msi_name, 'reader', @ext_appWorkspace, @ext_appName;
        END
    IF (@ext_service_principal_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Service principal name : ' + @ext_service_principal_name
            );
        END

    -- ROLES ON EXT WORKSPACES
    PRINT ('[EXT] Assigning Extension users roles on Extension workspace for extension: ' + @ext_name)
    IF (@ext_admin_group_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Admin group Name: '
                + @ext_admin_group_name
                + ' for: '
                + @ext_name
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @ext_name, @ext_admin_group_name, 'writer', @ext_appWorkspace, @ext_appName;
        END
    IF (@ext_operations_group_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Operations group name: '
                + @ext_operations_group_name
                + ' for: '
                + @ext_name
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @ext_name, @ext_operations_group_name, 'writer', @ext_appWorkspace, @ext_appName;
        END
    IF (@ext_contributor_group_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Contributor group name : '
                + @ext_contributor_group_name
                + ' for: '
                + @ext_name
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @ext_name, @ext_contributor_group_name, 'writer', @ext_appWorkspace, @ext_appName;
        END
    IF (@ext_reader_group_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Reader group name: '
                + @ext_reader_group_name
                + ' for: '
                + @ext_name
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @ext_name, @ext_reader_group_name, 'reader', @ext_appWorkspace, @ext_appName;
        END
    IF (@ext_synapse_workspace_msi_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Synapse workspace msi name: '
                + @ext_synapse_workspace_msi_name
                + ' for: '
                + @ext_name
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @ext_name, @ext_synapse_workspace_msi_name, 'writer', @ext_appWorkspace, @ext_appName;
        END
    IF (@ext_service_principal_name <> '#')
        BEGIN
            PRINT (
                '[EXT] Service principal name : '
                + @ext_service_principal_name
                + ' for: '
                + @ext_name
            );
            EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
                @ext_name, @ext_service_principal_name, 'schema_deployer', @ext_appWorkspace, @ext_appName;
        END
    PRINT ('[EXT] Finished assigning roles to identity users for the extension: ' + @ext_name);

    -- complete log
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';
  END TRY
  BEGIN CATCH
    DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @error_severity INT = ERROR_SEVERITY();
    DECLARE @error_state INT = ERROR_STATE();
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_message', @error_message
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_severity', @error_severity
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_state', @error_state
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'failure';
    --- then throw again to forward error
    THROW;
  END CATCH
END
GO

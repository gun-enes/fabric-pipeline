CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_ext_spf_user_role_assignments]
(
    @ext_name NVARCHAR(100)
)
AS
BEGIN
    DECLARE @cmd NVARCHAR(MAX);
    DECLARE @ext_appName AS NVARCHAR(100);
    DECLARE @ext_appWorkspace AS NVARCHAR(100);
    DECLARE @ext_contributor_group_name AS NVARCHAR(100);
    DECLARE @ext_synapse_workspace_msi_name AS NVARCHAR(100);

    SELECT
        @ext_appName = [workspace_name],
        @ext_appWorkspace = [workspace_name],
        @ext_contributor_group_name = [contributor_group_name],
        @ext_synapse_workspace_msi_name = [synapse_workspace_msi_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_name] = @ext_name;

    BEGIN
        PRINT ('[EXT] [SPF only] Assigning roles to the Synapse Workspace MSI for extension: ' + @ext_name)
        --additional SPF roles for ext_synapse_workspace_msi_name
        EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
            'core_ext001_harmonized-schema-writer', @ext_synapse_workspace_msi_name, 'generic', @ext_appWorkspace, @ext_appName;
        --additional SPF roles for ext contributor
        EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
            'core_ext001_harmonized-schema-writer', @ext_contributor_group_name, 'generic', @ext_appWorkspace, @ext_appName;

        --we are moving reporting users outisde of the schema loops as we will for now add reporting as reader to only 1x schemas:
        --<extPrefix>_cl_reporting
        PRINT ('[EXT] [SPF only] Assigning roles to the Reporting Group for extension: ' + @ext_name)
        SET
            @cmd
            = (SELECT
                STRING_AGG(
                    CAST(
                        CONCAT(
                            'EXEC [mgmt_xtinfra].[sp_infra_login_sync_role] ''',
                            @ext_name,
                            '_cl_reporting'', ',
                            QUOTENAME([reporting_group_name], ''''),
                            ', ''reader'', ',
                            QUOTENAME(@ext_appWorkspace, ''''),
                            ', ',
                            QUOTENAME(@ext_appName, '''')
                        ) AS NVARCHAR(MAX)
                    ),
                    CHAR(10)
                )
            FROM [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
            WHERE [workspace_name] = @ext_name)
        EXEC (@cmd)
    END
END
GO

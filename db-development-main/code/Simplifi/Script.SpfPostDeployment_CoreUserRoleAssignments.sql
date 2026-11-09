BEGIN
    DECLARE @cmd NVARCHAR(MAX);
    DECLARE @core_contributor_group_name AS NVARCHAR(100);
    DECLARE @core_appWorkspace AS NVARCHAR(100);
    DECLARE @core_appName AS NVARCHAR(100);

    --set variables
    SELECT
        @core_appName = [workspace_name],
        @core_appWorkspace = [workspace_name],
        @core_contributor_group_name = [contributor_group_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core';

    PRINT ('[CORE] [SPF only] Assigning roles to the Contributor Group')
    EXEC [mgmt_xtinfra].[sp_infra_login_sync_role]
        'mgmt_xtinfra-schema-reader', @core_contributor_group_name, 'generic', @core_appWorkspace, @core_appName;

    --we are moving reporting users outside of the schema loops as we will for now add reporting as reader to only 1x Core schemas:
    --core_cl_reporting
    PRINT ('[CORE] [SPF only] Assigning roles to the Reporting Group')
    SELECT
        @cmd = STRING_AGG(
            CAST(
                CONCAT(
                    'EXEC [mgmt_xtinfra].[sp_infra_login_sync_role] ''core_cl_reporting'', ',
                    QUOTENAME([reporting_group_name], ''''),
                    ', ''reader'', ',
                    QUOTENAME(@core_appWorkspace, ''''),
                    ', ',
                    QUOTENAME(@core_appName, '''')
                ) AS NVARCHAR(MAX)
            ),
            CHAR(10)
        )
    FROM [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
    WHERE [workspace_type] = 'core'
    EXEC (@cmd);
END

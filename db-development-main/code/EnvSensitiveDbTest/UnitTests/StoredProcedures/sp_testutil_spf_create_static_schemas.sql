CREATE PROCEDURE [mgmt_xtinfra].[sp_testutil_spf_create_static_schemas]
AS
BEGIN
    DECLARE @cmd NVARCHAR(MAX);
    PRINT ('[EXTENSION][SPF Only] Creating static schemas');
    SET @cmd = (
        SELECT
            STRING_AGG(
                CAST(CONCAT(
                    'EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] ''upgrade'', 0, 9999, ''',
                    [wks].[workspace_name],
                    '_',
                    [sch].[schema_name],
                    ''''
                ) AS NVARCHAR(MAX)),
                CHAR(10)
            )
        FROM [mgmt_xtinfra].[infra_static_ext_schemas] AS [sch]
        CROSS JOIN [mgmt_xtinfra].[infra_workspace_identity_config] AS [wks]
        WHERE [wks].[workspace_name] = 'tsqltest'
    );
    EXEC (@cmd);

    PRINT ('[EXTENSION][SPF Only] Upgrade links between static schemas and extension workspaces');
    SET @cmd = (
        SELECT
            STRING_AGG(
                CAST(CONCAT(
                    'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''upgrade'', 0, 9999, ',
                    QUOTENAME([wks].[workspace_name], ''''),
                    ', ''reader'', ''',
                    [wks].[workspace_name], '_', [sch].[schema_name],
                    ''', ''reader'''
                ) AS NVARCHAR(MAX)),
                CHAR(10)
            )
        FROM [mgmt_xtinfra].[infra_static_ext_schemas] AS [sch]
        CROSS JOIN [mgmt_xtinfra].[infra_workspace_identity_config] AS [wks]
        WHERE [wks].[workspace_name] = 'tsqltest'
    );
    EXEC (@cmd);

    SET @cmd = (
        SELECT
            STRING_AGG(
                CAST(CONCAT(
                    'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''upgrade'', 0, 9999, ',
                    QUOTENAME([wks].[workspace_name], ''''),
                    ', ''writer'', ''',
                    [wks].[workspace_name], '_', [sch].[schema_name],
                    ''', ''writer'''
                ) AS NVARCHAR(MAX)),
                CHAR(10)
            )
        FROM [mgmt_xtinfra].[infra_static_ext_schemas] AS [sch]
        CROSS JOIN [mgmt_xtinfra].[infra_workspace_identity_config] AS [wks]
        WHERE [wks].[workspace_name] = 'tsqltest'
    );
    EXEC (@cmd);

    SET @cmd = (
        SELECT
            STRING_AGG(
                CAST(CONCAT(
                    'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''upgrade'', 0, 9999, ',
                    QUOTENAME([wks].[workspace_name], ''''),
                    ', ''deployer'', ''',
                    [wks].[workspace_name], '_', [sch].[schema_name],
                    ''', ''deployer'''
                ) AS NVARCHAR(MAX)),
                CHAR(10)
            )
        FROM [mgmt_xtinfra].[infra_static_ext_schemas] AS [sch]
        CROSS JOIN [mgmt_xtinfra].[infra_workspace_identity_config] AS [wks]
        WHERE [wks].[workspace_name] = 'tsqltest'
    );
    EXEC (@cmd);

    PRINT ('[EXTENSION][SPF Only] Finished creating static schemas');
END
GO

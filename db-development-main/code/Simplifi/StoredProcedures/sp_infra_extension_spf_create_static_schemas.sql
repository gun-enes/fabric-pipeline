CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_extension_spf_create_static_schemas]
AS
BEGIN
    DECLARE @cmd NVARCHAR(MAX);

    PRINT ('[EXTENSION][SPF Only] Creating static schemas');
    SET @cmd = (
        SELECT STRING_AGG(
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
        WHERE [wks].[workspace_type] = 'extension'
    );
    EXEC (@cmd);

    PRINT ('[EXTENSION][SPF Only] Link static schemas to the extension workspaces');
    PRINT ('[EXTENSION][SPF Only] Link READER roles');
    SET @cmd = (
        SELECT STRING_AGG(
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
        WHERE [wks].[workspace_type] = 'extension'
    );
    EXEC (@cmd);

    PRINT ('[EXTENSION][SPF Only] Link WRITER roles');
    SET @cmd = (
        SELECT STRING_AGG(
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
        WHERE [wks].[workspace_type] = 'extension'
    );
    EXEC (@cmd);

    PRINT ('[EXTENSION][SPF Only] Link DEPLOYER roles');
    SET @cmd = (
        SELECT STRING_AGG(
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
        WHERE [wks].[workspace_type] = 'extension'
    );
    EXEC (@cmd);

    PRINT ('[EXTENSION][SPF Only] Finished creating static schemas');
END
GO

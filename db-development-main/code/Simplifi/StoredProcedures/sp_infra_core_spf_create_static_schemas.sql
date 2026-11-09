CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_core_spf_create_static_schemas]
AS
BEGIN
    DECLARE @cmd NVARCHAR(MAX);

    PRINT ('[CORE][SPF Only] Creating static schemas');
    SET @cmd = (
        SELECT STRING_AGG(
            CAST(CONCAT(
                'EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] ''upgrade'', 0, 9999, ',
                QUOTENAME([schema_name], '''')
            ) AS NVARCHAR(MAX)),
            CHAR(10)
        )
        FROM [mgmt_xtinfra].[infra_static_core_schemas]
    );
    EXEC (@cmd);

    PRINT ('[CORE][SPF Only] Link static schemas to the core workspace');
    PRINT ('[CORE][SPF Only] Link READER roles');
    SET @cmd = (
        SELECT STRING_AGG(
            CAST(CONCAT(
                'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''upgrade'', 0, 9999, ',
                QUOTENAME([wks].[workspace_name], ''''),
                ', ''reader'', ',
                QUOTENAME([sch].[schema_name], ''''),
                ', ''reader'''
            ) AS NVARCHAR(MAX)),
            CHAR(10)
        )
        FROM [mgmt_xtinfra].[infra_static_core_schemas] AS [sch]
        CROSS JOIN [mgmt_xtinfra].[infra_workspace_identity_config] AS [wks]
        WHERE [wks].[workspace_type] = 'core'
    );
    EXEC (@cmd);

    PRINT ('[CORE][SPF Only] Link WRITER roles');
    SET @cmd = (
        SELECT STRING_AGG(
            CAST(CONCAT(
                'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''upgrade'', 0, 9999, ',
                QUOTENAME([wks].[workspace_name], ''''),
                ', ''writer'', ',
                QUOTENAME([sch].[schema_name], ''''),
                ', ''writer'''
            ) AS NVARCHAR(MAX)),
            CHAR(10)
        )
        FROM [mgmt_xtinfra].[infra_static_core_schemas] AS [sch]
        CROSS JOIN [mgmt_xtinfra].[infra_workspace_identity_config] AS [wks]
        WHERE [wks].[workspace_type] = 'core'
    );
    EXEC (@cmd);

    PRINT ('[CORE][SPF Only] Link DEPLOYER roles');
    SET @cmd = (
        SELECT STRING_AGG(
            CAST(CONCAT(
                'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''upgrade'', 0, 9999, ',
                QUOTENAME([wks].[workspace_name], ''''),
                ', ''deployer'', ',
                QUOTENAME([sch].[schema_name], ''''),
                ', ''deployer'''
            ) AS NVARCHAR(MAX)),
            CHAR(10)
        )
        FROM [mgmt_xtinfra].[infra_static_core_schemas] AS [sch]
        CROSS JOIN [mgmt_xtinfra].[infra_workspace_identity_config] AS [wks]
        WHERE [wks].[workspace_type] = 'core'
    );
    EXEC (@cmd);

    PRINT ('[CORE][SPF Only] Finished creating static schemas');
END
GO

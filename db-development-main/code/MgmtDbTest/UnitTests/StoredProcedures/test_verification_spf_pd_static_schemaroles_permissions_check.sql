--Test SPF static core and extension schemaroles permissions on schema check
CREATE PROCEDURE [UnitTests].[test_verification_spf_pd_static_schemaroles_permissions_check]
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = 'runtime_mode' and [value] = 'SPF'
    )
    BEGIN
        PRINT ('Executing Test: test_verification_spf_pd_static_schemaroles_permissions_check');

        IF OBJECT_ID('tempdb..#StaticSchemas') IS NOT NULL
            DROP TABLE [#StaticSchemas];

        SELECT [t].[schema_name]
        INTO [#StaticSchemas]
        FROM (
                SELECT [schema_name]
                FROM [mgmt_xtinfra].[infra_static_core_schemas]
                UNION
                SELECT CONCAT([ws].[workspace_name], '_', [se].[schema_name]) AS [schema_name]
                FROM [mgmt_xtinfra].[infra_static_ext_schemas] AS [se]
                CROSS JOIN [mgmt_xtinfra].[infra_workspace_identity_config] AS [ws]
                WHERE [ws].[workspace_type] = 'extension'
            ) AS [t]

        CREATE TABLE #StaticSchemaPermissions(
            [RoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
            [PermissionName] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
            [PermissionClass] NVARCHAR(60) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
            [PermissionObjectName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
        )

        -- Add workspace-reader permissions on schema
        DECLARE @reader_schema_permissions varchar(4000)= N'[
            "SELECT",
            "VIEW DEFINITION"
            ]' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 ;

        INSERT INTO #StaticSchemaPermissions
        SELECT [schema_name] + '-schema-reader', [reader_permissions], 'SCHEMA', [schema_name]
        FROM [#StaticSchemas]
        CROSS JOIN OPENJSON (@reader_schema_permissions) WITH ([reader_permissions] nvarchar(128) '$')

        -- Add workspace-writer permissions on schema
        DECLARE @writer_schema_permissions varchar(4000)= N'[
            "SELECT",
            "VIEW DEFINITION",
            "ALTER",
            "DELETE",
            "EXECUTE",
            "INSERT",
            "REFERENCES",
            "UPDATE"
            ]' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 ;

        INSERT INTO #StaticSchemaPermissions
        SELECT [schema_name] + '-schema-writer', [writer_permissions], 'SCHEMA', [schema_name]
        FROM [#StaticSchemas]
        CROSS JOIN OPENJSON (@writer_schema_permissions) WITH ([writer_permissions] nvarchar(128) '$')

        -- Add workspace-writer permissions on database
        DECLARE @writer_db_permissions varchar(4000)= N'[
            "CREATE FUNCTION",
            "CREATE TABLE",
            "CREATE PROCEDURE",
            "CREATE VIEW"
            ]' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 ;

        INSERT INTO #StaticSchemaPermissions
        SELECT [schema_name] + '-schema-writer', [writer_permissions], 'DATABASE', DB_NAME()
        FROM [#StaticSchemas]
        CROSS JOIN OPENJSON (@writer_db_permissions) WITH ([writer_permissions] nvarchar(128) '$')

        -- Add workspace-deployer permissions on schema
        DECLARE @deployer_schema_permissions varchar(4000)= N'[
            "ALTER",
            "CONTROL"
            ]' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 ;

        INSERT INTO #StaticSchemaPermissions
        SELECT [schema_name] + '-schema-deployer', [deployer_permissions], 'SCHEMA', [schema_name]
        FROM [#StaticSchemas]
        CROSS JOIN OPENJSON (@deployer_schema_permissions) WITH ([deployer_permissions] nvarchar(128) '$')

        -- Check permission assignments
        SELECT
            [RoleName],
            [PermissionName],
            [PermissionClass],
            [PermissionObjectName]
        INTO [UnitTests].[UnassignedStaticSchemaPermissions]
        FROM [#StaticSchemaPermissions]
        EXCEPT
        SELECT
            [prin].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [RoleName],
            [perm].[permission_name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [PermissionName],
            [perm].[class_desc] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [PermissionClass],
            CASE
                WHEN class_desc = 'DATABASE' THEN DB_NAME([perm].[major_id])
                WHEN class_desc = 'SCHEMA' THEN SCHEMA_NAME([perm].[major_id])
            END COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [PermissionObjectName]
        FROM
            [sys].[database_permissions] AS [perm]
        INNER JOIN
            [sys].[database_principals] AS [prin]
        ON
            [perm].[grantee_principal_id] = [prin].[principal_id]
        WHERE
            [prin].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [RoleName] FROM [#StaticSchemaPermissions])
            AND [perm].[state] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'G'

        PRINT ('Static Schema Roles that have unassigned permissions are given below')
        -- Table should be empty if all roles have expected permissions assigned
        EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.UnassignedStaticSchemaPermissions'
    END
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_spf_pd_static_schemaroles_permissions_check]
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = 'runtime_mode' and [value] = 'SPF'
    )
    BEGIN
        PRINT ('Executing Rollback: rollback_test_verification_spf_pd_static_schemaroles_permissions_check')
        DROP TABLE [UnitTests].[UnassignedStaticSchemaPermissions]
    END
END;
GO

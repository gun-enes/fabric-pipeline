--Check if all service principals (mgmt, core, ext) are assigned exactly to required roles and not assigned to any extra role
CREATE PROCEDURE [UnitTests].[test_verification_roles_check_service_principal]
AS
BEGIN
    PRINT ('Executing Test: test_verification_roles_check_service_principal')
    DECLARE @core_sp NVARCHAR(128);

    CREATE TABLE [#ExpectedSPRoles] (
        [SpName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [DatabaseRoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = HASH([SpName]));

    --get core sp_name and workspace_name
    SELECT @core_sp = [service_principal_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core'

    --no mgmt roles

    --add core roles
    INSERT INTO [#ExpectedSPRoles]
    VALUES (@core_sp, 'Role_SchemaDeployer');

    INSERT INTO [#ExpectedSPRoles]
    VALUES (@core_sp, 'Role_ExternalDataCreator');

    INSERT INTO [#ExpectedSPRoles]
    VALUES (@core_sp, 'Role_AlterAnyDataspace');

    INSERT INTO [#ExpectedSPRoles]
    VALUES (@core_sp, 'Role_AdhocGroupClassifier');

    INSERT INTO [#ExpectedSPRoles]
    SELECT
        @core_sp,
        [workspace_name] + '-schema-deployer'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core'

    --add extension roles
    INSERT INTO [#ExpectedSPRoles]
    SELECT
        [service_principal_name],
        'Role_SchemaDeployer'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedSPRoles]
    SELECT
        [service_principal_name],
        'Role_ExternalDataCreator'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedSPRoles]
    SELECT
        [service_principal_name],
        'Role_AlterAnyDataspace'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedSPRoles]
    SELECT
        [service_principal_name],
        'Role_AdhocGroupClassifier'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedSPRoles]
    SELECT
        [service_principal_name],
        [workspace_name] + '-schema-deployer'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    -- remove duplicates from expected table
    DELETE [t]
    FROM
        (
            SELECT
                *,
                [DupRank] = ROW_NUMBER() OVER (
                    PARTITION BY [SpName], [DatabaseRoleName]
                    ORDER BY (SELECT NULL)
                )
            FROM [#ExpectedSPRoles]
        ) AS [t]
    WHERE [DupRank] > 1

    --assigned role-membership pairs exist in database for service principal
    SELECT
        [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [SpName],
        [DP1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [DatabaseRoleName]
    INTO [#AssignedSpRoles]
    FROM [sys].[database_role_members] AS [DRM]
    RIGHT OUTER JOIN [sys].[database_principals] AS [DP1]
        ON [DRM].[role_principal_id] = [DP1].[principal_id]
    LEFT OUTER JOIN [sys].[database_principals] AS [DP2]
        ON [DRM].[member_principal_id] = [DP2].[principal_id]
    WHERE
        [DP1].[type] = 'R'
        AND [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [SpName] FROM [#ExpectedSPRoles])

    PRINT (
        'The difference between assigned and expected roles for Service Principals are given below. _m_ column denotes whether the expected role is missing (<), unexpected role assignment (>) or correct assignment (=)'
    )
    -- Tables should be equal if all roles are correctly assigned to the sp user
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedSPRoles', '#AssignedSpRoles'
END;
GO

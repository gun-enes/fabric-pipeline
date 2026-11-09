--Check if all actions groups (mgmt, core, ext) are assigned exactly to required roles and not assigned to any extra role
CREATE PROCEDURE [UnitTests].[test_verification_roles_check_actions_group]
AS
BEGIN
    PRINT ('Executing Test: test_verification_roles_check_actions_group')
    DECLARE @core_actions_group NVARCHAR(128);

    CREATE TABLE [#ExpectedActionsRoles] (
        [actionsGroupName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [DatabaseRoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = HASH([actionsGroupName]));

    --get actions_group_name
    SELECT
        @core_actions_group = [actions_group_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core'

    --add core roles
    INSERT INTO [#ExpectedActionsRoles]
    VALUES (@core_actions_group, 'Role_ExternalDataCreator');

    INSERT INTO [#ExpectedActionsRoles]
    VALUES (@core_actions_group, 'Role_ActionsExecutor');

    --assigned role-membership pairs exist in database for actions groups
    SELECT
        [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [actionsGroupName],
        [DP1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [DatabaseRoleName]
    INTO [#AssignedActionsRoles]
    FROM [sys].[database_role_members] AS [DRM]
    RIGHT OUTER JOIN [sys].[database_principals] AS [DP1]
        ON [DRM].[role_principal_id] = [DP1].[principal_id]
    LEFT OUTER JOIN [sys].[database_principals] AS [DP2]
        ON [DRM].[member_principal_id] = [DP2].[principal_id]
    WHERE
        [DP1].[type] = 'R'
        AND [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [actionsGroupName] FROM [#ExpectedActionsRoles])

    PRINT (
        'The difference between assigned and expected roles for actions Groups are given below. _m_ column denotes whether the expected role is missing (<), unexpected role assignment (>) or correct assignment (=)'
    )
    -- Tables should be equal if all roles are correctly assigned to actions groups
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedActionsRoles', '#AssignedActionsRoles'
END;
GO

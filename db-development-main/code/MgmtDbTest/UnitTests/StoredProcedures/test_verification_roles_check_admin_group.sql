--Check if all admin groups (mgmt, core, ext) are assigned exactly to required roles and not assigned to any extra role
CREATE PROCEDURE [UnitTests].[test_verification_roles_check_admin_group]
AS
BEGIN
    PRINT ('Executing Test: test_verification_roles_check_admin_group')
    DECLARE @core_admin NVARCHAR(128);
    DECLARE @core_workspace NVARCHAR(128);
    DECLARE @core_workspace_writer NVARCHAR(128);

    CREATE TABLE [#ExpectedAdminRoles] (
        [AdminGroupName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [DatabaseRoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = HASH([AdminGroupName]));

    --get admin_group_name and workspace_name
    SELECT
        @core_admin = [admin_group_name],
        @core_workspace = [workspace_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core'

    --add core roles
    INSERT INTO [#ExpectedAdminRoles]
    VALUES (@core_admin, 'Role_ViewDatabaseState');

    INSERT INTO [#ExpectedAdminRoles]
    VALUES (@core_admin, 'Role_SHOWPLAN');

    INSERT INTO [#ExpectedAdminRoles]
    VALUES (@core_admin, 'Role_ExternalDataCreator');

    INSERT INTO [#ExpectedAdminRoles]
    VALUES (@core_admin, 'Role_AlterAnyDataspace');

    INSERT INTO [#ExpectedAdminRoles]
    VALUES (@core_admin, 'Role_VIEWDEFINITION');

    INSERT INTO [#ExpectedAdminRoles]
    VALUES (@core_admin, 'Role_SparkConnector');

    INSERT INTO [#ExpectedAdminRoles]
    VALUES (@core_admin, 'Role_OtherGroupClassifier');

    SET @core_workspace_writer = @core_workspace + '-schema-writer';
    INSERT INTO [#ExpectedAdminRoles]
    VALUES (@core_admin, @core_workspace_writer);

    INSERT INTO [#ExpectedAdminRoles]
    SELECT
        @core_admin,
        [workspace_name] + '-schema-reader'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    --add extension roles
    INSERT INTO [#ExpectedAdminRoles]
    SELECT
        [admin_group_name],
        [workspace_name] + '-schema-writer'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedAdminRoles]
    SELECT
        [admin_group_name],
        @core_workspace + '-schema-reader'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedAdminRoles]
    SELECT
        [admin_group_name],
        'Role_ViewDatabaseState'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedAdminRoles]
    SELECT
        [admin_group_name],
        'Role_SHOWPLAN'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedAdminRoles]
    SELECT
        [admin_group_name],
        'Role_ExternalDataCreator'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedAdminRoles]
    SELECT
        [admin_group_name],
        'Role_AlterAnyDataspace'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedAdminRoles]
    SELECT
        [admin_group_name],
        'Role_VIEWDEFINITION'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedAdminRoles]
    SELECT
        [admin_group_name],
        'Role_SparkConnector'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedAdminRoles]
    SELECT
        [admin_group_name],
        'Role_OtherGroupClassifier'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    -- remove duplicates from expected table
    DELETE [t]
    FROM
        (
            SELECT
                *,
                [DupRank] = ROW_NUMBER() OVER (
                    PARTITION BY [AdminGroupName], [DatabaseRoleName]
                    ORDER BY (SELECT NULL)
                )
            FROM [#ExpectedAdminRoles]
        ) AS [t]
    WHERE [DupRank] > 1

    --assigned role-membership pairs exist in database for admin groups
    SELECT
        [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [AdminGroupName],
        [DP1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [DatabaseRoleName]
    INTO [#AssignedAdminRoles]
    FROM [sys].[database_role_members] AS [DRM]
    RIGHT OUTER JOIN [sys].[database_principals] AS [DP1]
        ON [DRM].[role_principal_id] = [DP1].[principal_id]
    LEFT OUTER JOIN [sys].[database_principals] AS [DP2]
        ON [DRM].[member_principal_id] = [DP2].[principal_id]
    WHERE
        [DP1].[type] = 'R'
        AND [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [AdminGroupName] FROM [#ExpectedAdminRoles])

    PRINT (
        'The difference between assigned and expected roles for Admin Groups are given below. _m_ column denotes whether the expected role is missing (<), unexpected role assignment (>) or correct assignment (=)'
    )
    -- Tables should be equal if all roles are correctly assigned to admin groups
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedAdminRoles', '#AssignedAdminRoles'
END;
GO

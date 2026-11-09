--Check if all operations groups (mgmt, core, ext) are assigned exactly to required roles and not assigned to any extra role
CREATE PROCEDURE [UnitTests].[test_verification_roles_check_operations_group]
AS
BEGIN
    PRINT ('Executing Test: test_verification_roles_check_operations_group')
    DECLARE @mgmt_operations NVARCHAR(128);
    DECLARE @core_operations NVARCHAR(128);
    DECLARE @core_workspace NVARCHAR(128);
    DECLARE @core_workspace_writer NVARCHAR(128);

    CREATE TABLE [#ExpectedOperationsRoles] (
        [OperationsGroupName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [DatabaseRoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = HASH([OperationsGroupName]));

    --get operations_group_name and workspace_name
    SELECT @mgmt_operations = [operations_group_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'management'

    SELECT
        @core_operations = [operations_group_name],
        @core_workspace = [workspace_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core'

    --add mgmt roles
    INSERT INTO [#ExpectedOperationsRoles]
    VALUES (@mgmt_operations, 'db_backupoperator');

    INSERT INTO [#ExpectedOperationsRoles]
    VALUES (@mgmt_operations, 'db_ddladmin');

    INSERT INTO [#ExpectedOperationsRoles]
    VALUES (@mgmt_operations, 'db_datawriter');

    INSERT INTO [#ExpectedOperationsRoles]
    VALUES (@mgmt_operations, 'db_datareader');

    --add core roles
    INSERT INTO [#ExpectedOperationsRoles]
    VALUES (@core_operations, 'Role_OtherGroupClassifier');

    SET @core_workspace_writer = @core_workspace + '-schema-writer';
    INSERT INTO [#ExpectedOperationsRoles]
    VALUES (@core_operations, @core_workspace_writer);

    INSERT INTO [#ExpectedOperationsRoles]
    SELECT
        @core_operations,
        [workspace_name] + '-schema-reader'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    --add extension roles
    INSERT INTO [#ExpectedOperationsRoles]
    SELECT
        [operations_group_name],
        [workspace_name] + '-schema-writer'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedOperationsRoles]
    SELECT
        [operations_group_name],
        @core_workspace + '-schema-reader'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedOperationsRoles]
    SELECT
        [operations_group_name],
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
                    PARTITION BY [OperationsGroupName], [DatabaseRoleName]
                    ORDER BY (SELECT NULL)
                )
            FROM [#ExpectedOperationsRoles]
        ) AS [t]
    WHERE [DupRank] > 1

    --assigned role-membership pairs exist in database for operations groups
    SELECT
        [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [OperationsGroupName], --all role-membership pairs exist in database
        [DP1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [DatabaseRoleName]
    INTO [#AssignedOperationsRoles]
    FROM [sys].[database_role_members] AS [DRM]
    RIGHT OUTER JOIN [sys].[database_principals] AS [DP1]
        ON [DRM].[role_principal_id] = [DP1].[principal_id]
    LEFT OUTER JOIN [sys].[database_principals] AS [DP2]
        ON [DRM].[member_principal_id] = [DP2].[principal_id]
    WHERE
        [DP1].[type] = 'R'
        AND [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [OperationsGroupName] FROM [#ExpectedOperationsRoles])

    PRINT (
        'The difference between assigned and expected roles for Operations Groups are given below. _m_ column denotes whether the expected role is missing (<), unexpected role assignment (>) or correct assignment (=)'
    )
    -- Tables should be equal if all roles are correctly assigned to operations groups
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedOperationsRoles', '#AssignedOperationsRoles'
END;
GO

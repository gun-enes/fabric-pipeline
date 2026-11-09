--Check if all contributor groups (mgmt, core, ext) are assigned exactly to required roles and not assigned to any extra role
CREATE PROCEDURE [UnitTests].[test_verification_roles_check_contributor_group]
AS
BEGIN
    PRINT ('Executing Test: test_verification_roles_check_contributor_group')
    DECLARE @mgmt_contributor NVARCHAR(128);
    DECLARE @core_contributor NVARCHAR(128);
    DECLARE @core_workspace NVARCHAR(128);
    DECLARE @core_workspace_writer NVARCHAR(128);

    CREATE TABLE [#ExpectedContributorRoles] (
        [ContributorGroupName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [DatabaseRoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = HASH([ContributorGroupName]));

    --get contributor_group_name and workspace_name
    SELECT @mgmt_contributor = [contributor_group_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'management'

    SELECT
        @core_contributor = [contributor_group_name],
        @core_workspace = [workspace_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core'

    --add mgmt roles
    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@mgmt_contributor, 'db_datareader');

    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@mgmt_contributor, 'db_ddladmin');

    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@mgmt_contributor, 'db_datawriter');

    --add core roles
    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@core_contributor, 'Role_ViewDatabaseState');

    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@core_contributor, 'Role_SHOWPLAN');

    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@core_contributor, 'Role_ExternalDataCreator');

    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@core_contributor, 'Role_AlterAnyDataspace');

    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@core_contributor, 'Role_VIEWDEFINITION');

    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@core_contributor, 'Role_SparkConnector');

    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@core_contributor, 'Role_AdhocGroupClassifier');

    SET @core_workspace_writer = @core_workspace + '-schema-writer';
    INSERT INTO [#ExpectedContributorRoles]
    VALUES (@core_contributor, @core_workspace_writer);

    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        @core_contributor,
        [workspace_name] + '-schema-reader'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    --add extension roles
    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        [contributor_group_name],
        [workspace_name] + '-schema-writer'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        [contributor_group_name],
        @core_workspace + '-schema-reader'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        [contributor_group_name],
        'Role_ViewDatabaseState'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        [contributor_group_name],
        'Role_SHOWPLAN'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        [contributor_group_name],
        'Role_ExternalDataCreator'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        [contributor_group_name],
        'Role_AlterAnyDataspace'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        [contributor_group_name],
        'Role_VIEWDEFINITION'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        [contributor_group_name],
        'Role_SparkConnector'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        [contributor_group_name],
        'mgmt_xtinfra-schema-reader'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedContributorRoles]
    SELECT
        [contributor_group_name],
        'Role_AdhocGroupClassifier'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    --add SPF additional core and extension roles if we are currently in SPF mode
    IF
        EXISTS (
            SELECT 1
            FROM [mgmt_xtinfra].[infra_global_config]
            WHERE [key] = 'runtime_mode' AND [value] = 'SPF'
        )
        BEGIN
            --core
            INSERT INTO [#ExpectedContributorRoles]
            VALUES (@core_contributor, 'mgmt_xtinfra-schema-reader');

            --extension
            INSERT INTO [#ExpectedContributorRoles]
            SELECT
                [contributor_group_name],
                'core_ext001_harmonized-schema-writer'
            FROM [mgmt_xtinfra].[infra_workspace_identity_config]
            WHERE [workspace_type] = 'extension'
        END

    -- remove duplicates from expected table
    DELETE [t]
    FROM
        (
            SELECT
                *,
                [DupRank] = ROW_NUMBER() OVER (
                    PARTITION BY [ContributorGroupName], [DatabaseRoleName]
                    ORDER BY (SELECT NULL)
                )
            FROM [#ExpectedContributorRoles]
        ) AS [t]
    WHERE [DupRank] > 1

    --assigned role-membership pairs exist in database for contributor groups
    SELECT
        [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [ContributorGroupName],
        [DP1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [DatabaseRoleName]
    INTO [#AssignedContributorRoles]
    FROM [sys].[database_role_members] AS [DRM]
    RIGHT OUTER JOIN [sys].[database_principals] AS [DP1]
        ON [DRM].[role_principal_id] = [DP1].[principal_id]
    LEFT OUTER JOIN [sys].[database_principals] AS [DP2]
        ON [DRM].[member_principal_id] = [DP2].[principal_id]
    WHERE
        [DP1].[type] = 'R'
        AND [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [ContributorGroupName] FROM [#ExpectedContributorRoles])

    PRINT (
        'The difference between assigned and expected roles for Contributor Groups are given below. _m_ column denotes whether the expected role is missing (<), unexpected role assignment (>) or correct assignment (=)'
    )
    -- Tables should be equal if all roles are correctly assigned to Contributor groups
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedContributorRoles', '#AssignedContributorRoles'
END;
GO

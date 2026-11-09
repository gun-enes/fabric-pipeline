--Check if all reader groups (mgmt, core, ext) are assigned exactly to required roles and not assigned to any extra role
CREATE PROCEDURE [UnitTests].[test_verification_roles_check_reader_group]
AS
BEGIN
    PRINT ('Executing Test: test_verification_roles_check_reader_group')
    DECLARE @core_reader NVARCHAR(128);
    DECLARE @core_workspace NVARCHAR(128);
    DECLARE @core_workspace_reader NVARCHAR(128);

    CREATE TABLE [#ExpectedReaderRoles] (
        [ReaderGroupName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [DatabaseRoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = HASH([ReaderGroupName]));

    --get reader_group_name and workspace_name
    SELECT
        @core_reader = [reader_group_name],
        @core_workspace = [workspace_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core'
    SET @core_workspace_reader = @core_workspace + '-schema-reader'

    --add mgmt roles
    INSERT INTO [#ExpectedReaderRoles]
    SELECT
        [reader_group_name],
        'db_datareader'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'management'

    --add core roles
    INSERT INTO [#ExpectedReaderRoles]
    VALUES (@core_reader, @core_workspace_reader);

    INSERT INTO [#ExpectedReaderRoles]
    VALUES (@core_reader, 'Role_RepoGroupClassifier')

    --add extension roles
    INSERT INTO [#ExpectedReaderRoles]
    SELECT
        [reader_group_name],
        [workspace_name] + '-schema-reader'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedReaderRoles]
    SELECT
        [reader_group_name],
        'Role_AdhocGroupClassifier'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    -- remove duplicates from expected table
    DELETE [t]
    FROM
        (
            SELECT
                *,
                [DupRank] = ROW_NUMBER() OVER (
                    PARTITION BY [ReaderGroupName], [DatabaseRoleName]
                    ORDER BY (SELECT NULL)
                )
            FROM [#ExpectedReaderRoles]
        ) AS [t]
    WHERE [DupRank] > 1

    --assigned role-membership pairs exist in database for reader groups
    SELECT
        [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [ReaderGroupName],
        [DP1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [DatabaseRoleName]
    INTO [#AssignedReaderRoles]
    FROM [sys].[database_role_members] AS [DRM]
    RIGHT OUTER JOIN [sys].[database_principals] AS [DP1]
        ON [DRM].[role_principal_id] = [DP1].[principal_id]
    LEFT OUTER JOIN [sys].[database_principals] AS [DP2]
        ON [DRM].[member_principal_id] = [DP2].[principal_id]
    WHERE
        [DP1].[type] = 'R'
        AND [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [ReaderGroupName] FROM [#ExpectedReaderRoles])

    PRINT (
        'The difference between assigned and expected roles for Reader Groups are given below. _m_ column denotes whether the expected role is missing (<), unexpected role assignment (>) or correct assignment (=)'
    )
    -- Tables should be equal if all roles are correctly assigned to reader groups
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedReaderRoles', '#AssignedReaderRoles'
END;
GO

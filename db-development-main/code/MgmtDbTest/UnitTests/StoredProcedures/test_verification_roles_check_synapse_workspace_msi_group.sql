--Check if all Synapse workspace MSIs (mgmt, core, ext) are assigned exactly to required roles and not assigned to any extra role
CREATE PROCEDURE [UnitTests].[test_verification_roles_check_synapse_workspace_msi_group]
AS
BEGIN
    PRINT ('Executing Test: test_verification_roles_check_synapse_workspace_msi_group')
    DECLARE @core_msi NVARCHAR(128);
    DECLARE @core_workspace NVARCHAR(128);
    DECLARE @core_workspace_reader NVARCHAR(128);

    CREATE TABLE [#ExpectedMsiRoles] (
        [MsiName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [DatabaseRoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = HASH([MsiName]));

    --get core msi name and workspace_name
    SELECT
        @core_msi = [synapse_workspace_msi_name],
        @core_workspace = [workspace_name]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core'

    SET @core_workspace_reader = @core_workspace + '-schema-reader';
    --no mgmt roles

    --add core roles
    INSERT INTO [#ExpectedMsiRoles]
    VALUES (@core_msi, 'Role_ViewDatabaseState');

    INSERT INTO [#ExpectedMsiRoles]
    VALUES (@core_msi, 'Role_AdministerDatabaseBulkOperations');

    INSERT INTO [#ExpectedMsiRoles]
    VALUES (@core_msi, 'Role_AlterAnyDataspace');

    INSERT INTO [#ExpectedMsiRoles]
    VALUES (@core_msi, 'Role_SparkConnector');

    INSERT INTO [#ExpectedMsiRoles]
    VALUES (@core_msi, 'Role_CriticalGroupClassifier');

    INSERT INTO [#ExpectedMsiRoles]
    SELECT
        @core_msi,
        [workspace_name] + '-schema-writer'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'core'

    INSERT INTO [#ExpectedMsiRoles]
    SELECT
        @core_msi,
        [workspace_name] + '-schema-reader'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    --add extension roles
    INSERT INTO [#ExpectedMsiRoles]
    SELECT
        [synapse_workspace_msi_name],
        'Role_ViewDatabaseState'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedMsiRoles]
    SELECT
        [synapse_workspace_msi_name],
        'Role_AdministerDatabaseBulkOperations'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedMsiRoles]
    SELECT
        [synapse_workspace_msi_name],
        'Role_AlterAnyDataspace'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedMsiRoles]
    SELECT
        [synapse_workspace_msi_name],
        'Role_SparkConnector'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedMsiRoles]
    SELECT
        [synapse_workspace_msi_name],
        'Role_CriticalGroupClassifier'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedMsiRoles]
    SELECT
        [synapse_workspace_msi_name],
        [workspace_name] + '-schema-writer'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    INSERT INTO [#ExpectedMsiRoles]
    SELECT
        [synapse_workspace_msi_name],
        @core_workspace_reader
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'extension'

    --add SPF additional extension roles if we are currently in SPF mode
    IF
        EXISTS (
            SELECT 1
            FROM [mgmt_xtinfra].[infra_global_config]
            WHERE [key] = 'runtime_mode' AND [value] = 'SPF'
        )
        BEGIN
            --extension
            INSERT INTO [#ExpectedMsiRoles]
            SELECT
                [synapse_workspace_msi_name],
                'core_ext001_harmonized-schema-writer'
            FROM
                [mgmt_xtinfra].[infra_workspace_identity_config]
            WHERE
                [workspace_type] = 'extension'
        END

    -- remove duplicates from expected table
    DELETE [t]
    FROM
        (
            SELECT
                *,
                [DupRank] = ROW_NUMBER() OVER (
                    PARTITION BY [MsiName], [DatabaseRoleName]
                    ORDER BY (SELECT NULL)
                )
            FROM [#ExpectedMsiRoles]
        ) AS [t]
    WHERE [DupRank] > 1

    --assigned role-membership pairs exist in database for synapse msi names
    SELECT
        [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [MsiName],
        [DP1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [DatabaseRoleName]
    INTO [#AssignedMsiRoles]
    FROM [sys].[database_role_members] AS [DRM]
    RIGHT OUTER JOIN [sys].[database_principals] AS [DP1]
        ON [DRM].[role_principal_id] = [DP1].[principal_id]
    LEFT OUTER JOIN [sys].[database_principals] AS [DP2]
        ON [DRM].[member_principal_id] = [DP2].[principal_id]
    WHERE
        [DP1].[type] = 'R'
        AND [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [MsiName] FROM [#ExpectedMsiRoles])

    PRINT (
        'The difference between assigned and expected roles for Synapse Msi Names are given below. _m_ column denotes whether the expected role is missing (<), unexpected role assignment (>) or correct assignment (=)'
    )
    -- Tables should be equal if all roles are correctly assigned to the msi user
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedMsiRoles', '#AssignedMsiRoles'
END;
GO

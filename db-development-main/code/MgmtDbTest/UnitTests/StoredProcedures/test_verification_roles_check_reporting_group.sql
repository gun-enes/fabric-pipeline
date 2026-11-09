--Check if all reporting groups (mgmt, core, ext) are assigned exactly to required roles and not assigned to any extra role
CREATE PROCEDURE [UnitTests].[test_verification_roles_check_reporting_group]
AS
BEGIN
    PRINT ('Executing Test: test_verification_roles_check_reporting_group')

    CREATE TABLE [#ExpectedReportingRoles] (
        [ReportingGroupName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [DatabaseRoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = HASH([ReportingGroupName]));

    INSERT INTO [#ExpectedReportingRoles]
    SELECT
        [RG].[reporting_group_name],
        'Role_RepoGroupClassifier'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config] AS [ID]
    INNER JOIN [mgmt_xtinfra].[infra_workspace_reporting_groups_config] AS [RG]
        ON [ID].[workspace_name] = [RG].[workspace_name]
    WHERE [ID].[workspace_type] = 'core'

    INSERT INTO [#ExpectedReportingRoles]
    SELECT
        [RG].[reporting_group_name],
        'Role_RepoGroupClassifier'
    FROM [mgmt_xtinfra].[infra_workspace_identity_config] AS [ID]
    INNER JOIN [mgmt_xtinfra].[infra_workspace_reporting_groups_config] AS [RG]
        ON [ID].[workspace_name] = [RG].[workspace_name]
    WHERE [ID].[workspace_type] = 'extension'

    --add SPF additional extension roles if we are currently in SPF mode
    IF
        EXISTS (
            SELECT 1
            FROM [mgmt_xtinfra].[infra_global_config]
            WHERE [key] = 'runtime_mode' AND [value] = 'SPF'
        )
        BEGIN
        --add extension roles
            INSERT INTO [#ExpectedReportingRoles]
            SELECT
                [RG].[reporting_group_name],
                [ID].[workspace_name] + '_cl_reporting-schema-reader'
            FROM [mgmt_xtinfra].[infra_workspace_identity_config] AS [ID]
            INNER JOIN [mgmt_xtinfra].[infra_workspace_reporting_groups_config] AS [RG]
                ON [ID].[workspace_name] = [RG].[workspace_name]
            WHERE [ID].[workspace_type] = 'extension'

            --add core roles
            INSERT INTO [#ExpectedReportingRoles]
            SELECT
                [RG].[reporting_group_name],
                'core_cl_reporting-schema-reader'
            FROM [mgmt_xtinfra].[infra_workspace_identity_config] AS [ID]
            INNER JOIN [mgmt_xtinfra].[infra_workspace_reporting_groups_config] AS [RG]
                ON [ID].[workspace_name] = [RG].[workspace_name]
            WHERE [ID].[workspace_type] = 'core'
        END

    -- remove duplicates from expected table
    DELETE [t]
    FROM
        (
            SELECT
                *,
                [DupRank] = ROW_NUMBER() OVER (
                    PARTITION BY [ReportingGroupName], [DatabaseRoleName]
                    ORDER BY (SELECT NULL)
                )
            FROM [#ExpectedReportingRoles]
        ) AS [t]
    WHERE [DupRank] > 1

    --assigned role-membership pairs exist in database for reporting groups
    SELECT
        [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [ReportingGroupName],
        [DP1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [DatabaseRoleName]
    INTO [#AssignedReportingRoles]
    FROM [sys].[database_role_members] AS [DRM]
    RIGHT OUTER JOIN [sys].[database_principals] AS [DP1]
        ON [DRM].[role_principal_id] = [DP1].[principal_id]
    LEFT OUTER JOIN [sys].[database_principals] AS [DP2]
        ON [DRM].[member_principal_id] = [DP2].[principal_id]
    WHERE
        [DP1].[type] = 'R'
        AND [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [ReportingGroupName] FROM [#ExpectedReportingRoles])

    PRINT (
        'The difference between assigned and expected roles for Reporting Groups are given below. _m_ column denotes whether the expected role is missing (<), unexpected role assignment (>) or correct assignment (=)'
    )
    -- Tables should be equal if all roles are correctly assigned to reporting groups
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedReportingRoles', '#AssignedReportingRoles'
END;
GO

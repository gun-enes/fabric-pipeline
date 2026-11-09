--Check if the TF plan service principal (management workspace) is assigned exactly to required roles and not assigned to any extra role
CREATE PROCEDURE [UnitTests].[test_verification_roles_check_service_principal_tf_plan]
AS
BEGIN
    PRINT ('Executing Test: test_verification_roles_check_service_principal_tf_plan')
    DECLARE @tf_plan_sp NVARCHAR(128);

    CREATE TABLE [#ExpectedSPTFRoles] (
        [SpName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [DatabaseRoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = HASH([SpName]));

    --get tf_plan sp_name from management workspace
    SELECT @tf_plan_sp = [service_principal_name_tf_plan]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] = 'management'

    --add expected role only when tf_plan sp is configured
    IF (@tf_plan_sp IS NOT NULL AND @tf_plan_sp <> '#')
        BEGIN
            INSERT INTO [#ExpectedSPTFRoles]
            VALUES (@tf_plan_sp, 'db_datareader');
        END

    --assigned role-membership pairs exist in database for tf plan service principal
    SELECT
        [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [SpName],
        [DP1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [DatabaseRoleName]
    INTO [#AssignedSpTFRoles]
    FROM [sys].[database_role_members] AS [DRM]
    RIGHT OUTER JOIN [sys].[database_principals] AS [DP1]
        ON [DRM].[role_principal_id] = [DP1].[principal_id]
    LEFT OUTER JOIN [sys].[database_principals] AS [DP2]
        ON [DRM].[member_principal_id] = [DP2].[principal_id]
    WHERE
        [DP1].[type] = 'R'
        AND [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [SpName] FROM [#ExpectedSPTFRoles])

    PRINT (
        'The difference between assigned and expected roles for the TF plan Service Principal are given below. _m_ column denotes whether the expected role is missing (<), unexpected role assignment (>) or correct assignment (=)'
    )
    -- Tables should be equal if all roles are correctly assigned to the tf plan sp user
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedSPTFRoles', '#AssignedSpTFRoles'
END;
GO

--Test workspace schemas are created
CREATE PROCEDURE [UnitTests].[test_verification_pd_workspace_schema_create_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_pd_workspace_schema_create_check');

    IF OBJECT_ID('tempdb..#Workspaces') IS NOT NULL
        DROP TABLE [#Workspaces];

    SELECT [workspace_name]
    INTO [#Workspaces]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] <> 'management'

    -- Check schema creation
    SELECT [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [workspace_name]
    INTO [#CreatedSchemas]
    FROM [sys].[schemas]
    WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [workspace_name] FROM [#Workspaces])

    PRINT (
        'The difference between created and expected Schemas for workspaces are given below. _m_ column denotes whether the expected Schema is missing (<), unexpected Schema creation (>) or correct assignment (=)'
    )
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#Workspaces', '#CreatedSchemas';
END;
GO

--Check if all workspaces have a corresponding schema
CREATE PROCEDURE [UnitTests].[test_verification_ss_workspace_object_has_related_schema_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_workspace_object_has_related_schema_check')
    SELECT DISTINCT *
    INTO [UnitTests].[WorkspacesWithoutSchema]
    FROM [mgmt_xtinfra].[infra_object_master] AS [wks]
    WHERE
        [type] = 'workspace' AND [version] <> 0
        AND NOT EXISTS (
            SELECT *
            FROM [mgmt_xtinfra].[infra_object_master] AS [sch]
            WHERE [sch].[type] = 'schema' AND [sch].[name] = [wks].[name] AND [sch].[version] <> 0
        )

    PRINT ('Workspaces that do not have schema are given below')
    -- Table should be empty if all workspaces has corresponding schema with same name
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.WorkspacesWithoutSchema'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_workspace_object_has_related_schema_check]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_workspace_object_has_related_schema_check')
    DROP TABLE [UnitTests].[WorkspacesWithoutSchema]
END;
GO

--Test workspace views are created
CREATE PROCEDURE [UnitTests].[test_verification_pd_workspace_view_create_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_pd_workspace_view_create_check');

    IF OBJECT_ID('tempdb..#Workspaces') IS NOT NULL
        DROP TABLE [#Workspaces];

    SELECT [workspace_name]
    INTO [#Workspaces]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] <> 'management'

    -- Check view creation
    DECLARE @view_names varchar(4000)= N'[
        "v_schedule",
        "v_expanded_schedule",
        "v_expanded_gatherstats_schedule"
        ]';

    SELECT [view_name], [workspace_name]
    INTO [#WorkspaceViews]
    FROM OPENJSON (@view_names) WITH ([view_name] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')
    CROSS JOIN [#Workspaces]

    SELECT [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [view_name], [workspace_name]
    INTO [#CreatedViews]
    FROM [sys].[views]
    CROSS JOIN [#Workspaces]
    WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [view_name] FROM [#WorkspaceViews])
    AND [type] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'V'
    AND SCHEMA_NAME([schema_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = [workspace_name]

    PRINT (
        'The difference between created and expected view for workspaces are given below. _m_ column denotes whether the expected view is missing (<), unexpected view creation (>) or correct assignment (=)'
    )
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#WorkspaceViews', '#CreatedViews';
END;
GO

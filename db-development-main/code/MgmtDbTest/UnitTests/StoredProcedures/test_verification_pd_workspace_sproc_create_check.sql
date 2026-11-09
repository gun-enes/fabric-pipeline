--Test workspace schemas are created
CREATE PROCEDURE [UnitTests].[test_verification_pd_workspace_sproc_create_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_pd_workspace_sproc_create_check');

    IF OBJECT_ID('tempdb..#Workspaces') IS NOT NULL
        DROP TABLE [#Workspaces];

    SELECT [workspace_name]
    INTO [#Workspaces]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] <> 'management'

    -- Check Stored Procedures creation
    DECLARE @stored_procedure_names varchar(4000)= N'[
        "sp_workspace_schema_order_create_or_update",
        "sp_workspace_schema_order_delete",
        "sp_workspace_rlspolicy_order_create_or_update",
        "sp_workspace_rlspolicy_order_delete",
        "sp_workspace_user_order_create_or_update",
        "sp_workspace_user_order_delete",
        "sp_workspace_schedule_delete",
        "sp_workspace_schedule_create",
        "sp_workspace_killsession_order_create_or_update",
        "sp_workspace_workloadclassifier_order_create_or_update",
        "sp_workspace_workloadclassifier_order_delete",
        "sp_workspace_workloadgroup_order_create_or_update",
        "sp_workspace_workloadgroup_order_delete",
        "sp_workspace_gatherstats_schedule_create",
        "sp_workspace_gatherstats_schedule_delete"
        ]';

    SELECT [stored_procedure_name], [workspace_name]
    INTO [#WorkspaceStoredProcedures]
    FROM OPENJSON (@stored_procedure_names) WITH ([stored_procedure_name] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')
    CROSS JOIN [#Workspaces]

    SELECT [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [stored_procedure_name], [workspace_name]
    INTO [#CreatedSPROCs]
    FROM [sys].[procedures]
    CROSS JOIN [#Workspaces]
    WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [stored_procedure_name] FROM [#WorkspaceStoredProcedures])
    AND [type] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'P'
    AND SCHEMA_NAME([schema_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = [workspace_name]

    PRINT (
        'The difference between created and expected Stored Procedures for workspaces are given below. _m_ column denotes whether the expected Stored Procedure is missing (<), unexpected Stored Procedure creation (>) or correct assignment (=)'
    )
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#WorkspaceStoredProcedures', '#CreatedSPROCs';
END;
GO

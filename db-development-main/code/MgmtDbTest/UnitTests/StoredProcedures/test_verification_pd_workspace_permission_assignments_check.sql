--Test workspace schemaroles are assigned adequate permissions
CREATE PROCEDURE [UnitTests].[test_verification_pd_workspace_permission_assignments_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_pd_workspace_permission_assignments_check');

    IF OBJECT_ID('tempdb..#Workspaces') IS NOT NULL
        DROP TABLE [#Workspaces];

    SELECT [workspace_name]
    INTO [#Workspaces]
    FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_type] <> 'management'

    CREATE TABLE [#WorkspacePermissions](
        [RoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [PermissionName] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [PermissionClass] NVARCHAR(60) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [PermissionObjectName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [SchemaName] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )

    -- Add workspace-reader permissions on schema
    DECLARE @reader_schema_permissions varchar(4000)= N'[
        "SELECT",
        "VIEW DEFINITION"
        ]';

    INSERT INTO #WorkspacePermissions
    SELECT [workspace_name] + '-schema-reader', [reader_permissions], 'SCHEMA', [workspace_name], NULL
    FROM [#Workspaces]
    CROSS JOIN OPENJSON (@reader_schema_permissions) WITH ([reader_permissions] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')

    -- Add workspace-writer permissions on schema
    DECLARE @writer_schema_permissions varchar(4000)= N'[
        "SELECT",
        "VIEW DEFINITION",
        "ALTER",
        "DELETE",
        "EXECUTE",
        "INSERT",
        "REFERENCES",
        "UPDATE"
        ]';

    INSERT INTO #WorkspacePermissions
    SELECT [workspace_name] + '-schema-writer', [writer_permissions], 'SCHEMA', [workspace_name], NULL
    FROM [#Workspaces]
    CROSS JOIN OPENJSON (@writer_schema_permissions) WITH ([writer_permissions] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')

    -- Add workspace-writer permissions on database
    DECLARE @writer_db_permissions varchar(4000)= N'[
        "CREATE FUNCTION",
        "CREATE TABLE",
        "CREATE PROCEDURE",
        "CREATE VIEW"
        ]';

    INSERT INTO #WorkspacePermissions
    SELECT [workspace_name] + '-schema-writer', [writer_permissions], 'DATABASE', DB_NAME(), NULL
    FROM [#Workspaces]
    CROSS JOIN OPENJSON (@writer_db_permissions) WITH ([writer_permissions] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')

    -- Add workspace-writer select permissions on objects
    DECLARE @writer_select_permission_objects varchar(4000)= N'[
        "v_schedule",
        "v_expanded_schedule",
        "v_expanded_gatherstats_schedule"
        ]';

    INSERT INTO #WorkspacePermissions
    SELECT [workspace_name] + '-schema-writer', 'SELECT', 'OBJECT_OR_COLUMN', [select_permission_object_name], [workspace_name]
    FROM [#Workspaces]
    CROSS JOIN OPENJSON (@writer_select_permission_objects) WITH ([select_permission_object_name] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')

    -- Add workspace-deployer permissions on schema
    DECLARE @deployer_schema_permissions varchar(4000)= N'[
        "ALTER",
        "CONTROL"
        ]';

    INSERT INTO #WorkspacePermissions
    SELECT [workspace_name] + '-schema-deployer', [deployer_permissions], 'SCHEMA', [workspace_name], NULL
    FROM [#Workspaces]
    CROSS JOIN OPENJSON (@deployer_schema_permissions) WITH ([deployer_permissions] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')

    -- Add execute permissions on dedicated workspaces
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

    INSERT INTO #WorkspacePermissions
    SELECT [workspace_name] + '-schema-deployer', 'EXECUTE', 'OBJECT_OR_COLUMN', [stored_procedure_name], [workspace_name]
    FROM [#Workspaces]
    CROSS JOIN OPENJSON (@stored_procedure_names) WITH ([stored_procedure_name] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')

    -- Add execute permissions on mgmt_xtinfra
    DECLARE @mgmt_xtinfra_exec varchar(4000)= N'[
        "sp_infra_schema_order_create_or_update",
        "sp_infra_rlspolicy_order_create_or_update",
        "sp_infra_rlspolicy_order_delete",
        "sp_infra_user_order_create_or_update",
        "sp_infra_user_order_delete",
        "sp_infra_schema_order_delete",
        "sp_infra_schedule_delete",
        "sp_infra_schedule_create",
        "sp_infra_job_log_execution",
        "sp_infra_job_log_execution_details",
        "InfraGetWorkspaceSchemaName",
        "InfraValidateCrontabMonth",
        "InfraValidateCrontabDayOfWeek",
        "InfraValidateCrontabDayOfMonth",
        "sp_infra_trigger_pipeline",
        "sp_infra_killsession_order_create_or_update",
        "sp_infra_workloadgroup_order_create_or_update",
        "sp_infra_workloadgroup_order_delete",
        "sp_infra_workloadclassifier_order_create_or_update",
        "sp_infra_workloadclassifier_order_delete",
        "sp_infra_gatherstats_schedule_delete",
        "sp_infra_gatherstats_schedule_create"
        ]';

    INSERT INTO #WorkspacePermissions
    SELECT [workspace_name] + '-schema-deployer', 'EXECUTE', 'OBJECT_OR_COLUMN', [mgmt_xtinfra_exec], 'mgmt_xtinfra'
    FROM [#Workspaces]
    CROSS JOIN OPENJSON (@mgmt_xtinfra_exec) WITH ([mgmt_xtinfra_exec] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')

    -- Add insert permissions on mgmt_xtinfra
    DECLARE @mgmt_xtinfra_insert varchar(4000)= N'[
        "infra_schedule",
        "infra_orders_details_users",
        "infra_job_master_v2_details",
        "infra_job_master_v2",
        "infra_orders_details_rlspolicy",
        "infra_orders_master",
        "infra_orders_details_schemas",
        "infra_orders_details_schemalinks",
        "infra_orders_details_schemaroles",
        "infra_orders_details_killsessions",
        "infra_orders_details_workloadclassifier",
        "infra_orders_details_workloadgroup",
        "infra_gatherstats_schedule_detail"
        ]';

    INSERT INTO #WorkspacePermissions
    SELECT [workspace_name] + '-schema-deployer', 'INSERT', 'OBJECT_OR_COLUMN', [mgmt_xtinfra_insert], 'mgmt_xtinfra'
    FROM [#Workspaces]
    CROSS JOIN OPENJSON (@mgmt_xtinfra_insert) WITH ([mgmt_xtinfra_insert] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')

    -- Add delete permissions on mgmt_xtinfra
    DECLARE @mgmt_xtinfra_delete varchar(4000)= N'[
        "infra_schedule",
        "infra_gatherstats_schedule_detail"
        ]';

    INSERT INTO #WorkspacePermissions
    SELECT [workspace_name] + '-schema-deployer', 'DELETE', 'OBJECT_OR_COLUMN', [mgmt_xtinfra_delete], 'mgmt_xtinfra'
    FROM [#Workspaces]
    CROSS JOIN OPENJSON (@mgmt_xtinfra_delete) WITH ([mgmt_xtinfra_delete] nvarchar(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$')

    --detect unassigned permissions
    SELECT
        [RoleName],
        [PermissionName],
        [PermissionClass],
        [PermissionObjectName],
        [SchemaName]
    INTO [UnitTests].[UnassignedWorkspacePermissions]
    FROM [#WorkspacePermissions]
    EXCEPT
    SELECT
        [prin].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [RoleName],
        [perm].[permission_name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [PermissionName],
        [perm].[class_desc] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [PermissionClass],
        CASE
            WHEN class_desc = 'DATABASE' THEN DB_NAME([perm].[major_id])
            WHEN class_desc = 'SCHEMA' THEN SCHEMA_NAME([perm].[major_id])
            WHEN class_desc = 'OBJECT_OR_COLUMN' THEN OBJECT_NAME([perm].[major_id])
        END COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [PermissionObjectName],
        SCHEMA_NAME([obj].[schema_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [SchemaName]
    FROM
        [sys].[database_permissions] AS [perm]
    INNER JOIN
        [sys].[database_principals] AS [prin]
    ON
        [perm].[grantee_principal_id] = [prin].[principal_id]
    LEFT JOIN
        [sys].[objects] AS [obj]
    ON
        [perm].[major_id] = [obj].[object_id]
    WHERE
        [prin].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [RoleName] FROM [#WorkspacePermissions])
        AND [perm].[state] = 'G'

    PRINT ('Workspace Roles that have unassigned permissions are given below')
    -- Table should be empty if all roles have expected permissions assigned
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.UnassignedWorkspacePermissions'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_pd_workspace_permission_assignments_check]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_pd_workspace_permission_assignments_check')
    DROP TABLE [UnitTests].[UnassignedWorkspacePermissions]
END;
GO

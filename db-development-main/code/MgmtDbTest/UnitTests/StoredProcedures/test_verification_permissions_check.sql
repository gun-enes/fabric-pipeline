--Check if all roles have exactly the assigned permissions, not extra permissions are assigned
CREATE PROCEDURE [UnitTests].[test_verification_permissions_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_permissions_check')
    DECLARE @db_name NVARCHAR(50) = DB_NAME();
    CREATE TABLE [#ExpectedPermissions] (
        [RoleName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [PermissionName] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [PermissionClass] NVARCHAR(60) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [PermissionObjectName] NVARCHAR(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = ROUND_ROBIN);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SHOWPLAN', 'SHOWPLAN', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ViewDatabaseState', 'VIEW DATABASE STATE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_AdministerDatabaseBulkOperations', 'ADMINISTER DATABASE BULK OPERATIONS', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_VIEWDEFINITION', 'VIEW DEFINITION', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ExternalDataCreator', 'ALTER ANY EXTERNAL FILE FORMAT', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ExternalDataCreator', 'ALTER ANY EXTERNAL DATA SOURCE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'ALTER ANY MASK', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'VIEW DATABASE STATE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'VIEW DEFINITION', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'CREATE TABLE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'CREATE VIEW', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'CREATE PROCEDURE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'CREATE FUNCTION', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'ALTER ANY EXTERNAL DATA SOURCE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'ALTER ANY SENSITIVITY CLASSIFICATION', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'VIEW ANY SENSITIVITY CLASSIFICATION', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'SELECT', 'SCHEMA', 'sys');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'SELECT', 'SCHEMA', 'INFORMATION_SCHEMA');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SchemaDeployer', 'SELECT', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_AlterAnyDataspace', 'ALTER ANY DATASPACE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SparkConnector', 'CREATE TABLE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SparkConnector', 'ALTER ANY EXTERNAL DATA SOURCE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SparkConnector', 'ALTER ANY EXTERNAL FILE FORMAT', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SparkConnector', 'ADMINISTER DATABASE BULK OPERATIONS', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_SparkConnector', 'ALTER', 'SCHEMA', 'SqlAnalyticsConnector');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'CREATE TABLE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'VIEW DATABASE STATE', 'DATABASE', @db_name);

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'SELECT', 'SCHEMA', 'sys');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'ALTER', 'SCHEMA', 'Actions');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'SCHEMA', 'Actions');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'SELECT', 'SCHEMA', 'Actions');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_job_log_execution');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_job_log_execution_details');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'INSERT', 'OBJECT_OR_COLUMN', 'infra_job_master_v2_details');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'INSERT', 'OBJECT_OR_COLUMN', 'infra_job_master_v2');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'INSERT', 'OBJECT_OR_COLUMN', 'infra_orders_details_killsessions');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'INSERT', 'OBJECT_OR_COLUMN', 'infra_orders_details_users');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'INSERT', 'OBJECT_OR_COLUMN', 'infra_orders_details_workloadclassifier');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'INSERT', 'OBJECT_OR_COLUMN', 'infra_orders_details_workloadgroup');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'INSERT', 'OBJECT_OR_COLUMN', 'infra_orders_master');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'SELECT', 'OBJECT_OR_COLUMN', 'infra_schedule');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'INSERT', 'OBJECT_OR_COLUMN', 'infra_schedule');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'DELETE', 'OBJECT_OR_COLUMN', 'infra_schedule');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'INSERT', 'OBJECT_OR_COLUMN', 'infra_config_settings');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'UPDATE', 'OBJECT_OR_COLUMN', 'infra_config_settings');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'SELECT', 'OBJECT_OR_COLUMN', 'infra_config_settings');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_killsession_order_create_or_update');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_user_order_create_or_update');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_user_order_delete');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_workloadclassifier_order_create_or_update');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_workloadclassifier_order_delete');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_workloadgroup_order_create_or_update');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_workloadgroup_order_delete');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_schedule_create');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_schedule_delete');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_trigger_pipeline');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'InfraValidateCrontabDayOfMonth');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'InfraValidateCrontabDayOfWeek');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'InfraValidateCrontabMonth');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_gatherstats_schedule_create');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_gatherstats_schedule_delete');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'EXECUTE', 'OBJECT_OR_COLUMN', 'sp_infra_set_config_setting');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'DELETE', 'OBJECT_OR_COLUMN', 'infra_gatherstats_schedule_detail');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'INSERT', 'OBJECT_OR_COLUMN', 'infra_gatherstats_schedule_detail');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'SELECT', 'OBJECT_OR_COLUMN', 'infra_gatherstats_schedule_detail');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'SELECT', 'OBJECT_OR_COLUMN', 'infra_global_config');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'SELECT', 'OBJECT_OR_COLUMN', 'infra_workspace_identity_config');

    INSERT INTO [#ExpectedPermissions]
    VALUES('Role_ActionsExecutor', 'SELECT', 'OBJECT_OR_COLUMN', 'infra_mgmt_version_config');

    INSERT INTO [#ExpectedPermissions]
    VALUES('mgmt_xtinfra-schema-reader', 'SELECT', 'OBJECT_OR_COLUMN', 'infra_dist_master');

    INSERT INTO [#ExpectedPermissions]
    VALUES('mgmt_xtinfra-schema-reader', 'SELECT', 'OBJECT_OR_COLUMN', 'infra_mgmt_version_config');

    --assigned role-permission pairs exist in database
    SELECT
        [prin].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [RoleName],
        [perm].[permission_name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [PermissionName],
        [perm].[class_desc] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [PermissionClass],
        CASE
            WHEN class_desc = 'DATABASE' THEN DB_NAME([perm].[major_id])
            WHEN class_desc = 'SCHEMA' THEN SCHEMA_NAME([perm].[major_id])
            WHEN class_desc = 'OBJECT_OR_COLUMN' THEN OBJECT_NAME([perm].[major_id])
        END COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [PermissionObjectName]
    INTO [#AssignedPermissions]
    FROM
        [sys].[database_permissions] AS [perm]
    INNER JOIN
        [sys].[database_principals] AS [prin]
    ON
        [perm].[grantee_principal_id] = [prin].[principal_id]
    WHERE
        [prin].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [RoleName] FROM [#ExpectedPermissions])
        AND [perm].[state] = 'G'

    PRINT (
        'The difference between assigned and expected permissions for Roles are given below. _m_ column denotes whether the expected permission is missing (<), unexpected permission assignment (>) or correct assignment (=)'
    )
    -- Tables should be equal if all permissions are correctly given to roles
    EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedPermissions', '#AssignedPermissions'
END;
GO

-- This file contains SQL statements that will be executed after the build script.
BEGIN
    --set runtime mode to be used in test projects
    EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] 'runtime_mode', 'SPF';
    PRINT ('This is Simplfi package execution');

    -- Execute SPF Post Deployment Scripts
    :r .\Script.SpfPostDeployment_ConfigTables.sql
    :r .\Script.SpfPostDeployment_CreateStaticSchemas.sql
    :r .\Script.SpfPostDeployment_CoreUserRoleAssignments.sql
    :r .\Script.SpfPostDeployment_ExtUserRoleAssignments.sql
    :r .\Script.SpfPostDeployment_DefaultSchedules.sql

    -- This script is for one-time only changes such as: cleanup operations for old codes etc.
    -- Should be removed after specified version is deployed to all environments
    -- Example script naming -> :r .\Script.PostDeployment_v1.4.1_TempOperations.sql

    print('[SPF_PKG_FINISHED]')
END

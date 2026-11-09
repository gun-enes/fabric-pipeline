-- This file contains SQL statements that will be executed after the build script.
BEGIN
    :r .\Script.PostDeployment_GlobalVariables.sql
    :r .\Script.PostDeployment_ConfigTables.sql
    :r .\Script.PostDeployment_MasterKey.sql
    :r .\Script.PostDeployment_Workspaces.sql
    :r .\Script2.PostDeployement_AdditionalSettings.sql
    :r .\Script.PostDeployment_MgmtUserRoleAssignments.sql
    :r .\Script.PostDeployment_CoreUserRoleAssignments.sql
    :r .\Script.PostDeployment_ExtUserRoleAssignments.sql
    :r .\Script.PostDeployment_WorkloadGroups.sql
    :r .\Script.PostDeployment_WorkloadClassifiers.sql
    :r .\Script.PostDeployment_CreateEDS.sql
    :r .\Script.PostDeployment_v2.0.2_TempOperationsWG.sql

    -- This script is for one-time only changes such as: cleanup operations for old codes etc.
    -- Should be removed after specified version is deployed to all environments
    -- Example script naming -> :r .\Script.PostDeployment_v1.4.1_TempOperations.sql

    print('[PKG_FINISHED]')
END

-- This file contains SQL statements that will be executed before the build script.
BEGIN
   print('Executing Pre Deployment scripts')
    :r .\Removal_stats_b4_Deployment.sql
    :r .\ModifyTables.PreDeployment.sql

    print('Completed Pre Deployment scripts')
END

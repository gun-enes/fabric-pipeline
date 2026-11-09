CREATE ROLE [Role_SHOWPLAN];
GO
--had to move to post script as error during build 'Build error SQL70594: The permission SHOWPLAN is not valid for object type Database in the targeted platform'
--GRANT SHOWPLAN to [Role_SHOWPLAN];
--GO
CREATE ROLE [Role_ViewDatabaseState];
GO
grant VIEW database STATE to [Role_ViewDatabaseState];
GO
CREATE ROLE [Role_AdministerDatabaseBulkOperations];
GO
--this won't work as package won't build: 'Cannot determine securable object class from permission ADMINISTER DATABASE BULK OPERATIONS'
--GRANT ADMINISTER DATABASE BULK OPERATIONS TO [Role_AdministerDatabaseBulkOperations];
--GO
CREATE ROLE [Role_VIEWDEFINITION];
GO
GRANT VIEW DEFINITION TO [Role_VIEWDEFINITION];
GO
CREATE ROLE [Role_ExternalDataCreator];
GO
GRANT ALTER ANY EXTERNAL DATA SOURCE,ALTER ANY EXTERNAL FILE FORMAT to [Role_ExternalDataCreator];
GO
CREATE ROLE [Role_SchemaDeployer];
GO
--EXEC sp_addrolemember [db_datawriter],[Role_SchemaDeployer];
--GO
GRANT SELECT ON SCHEMA::[sys] TO [Role_SchemaDeployer];
GO
GRANT SELECT ON SCHEMA::[INFORMATION_SCHEMA] TO [Role_SchemaDeployer];
GO
GRANT VIEW DATABASE STATE,VIEW  DEFINITION,CREATE TABLE,CREATE VIEW,CREATE PROCEDURE,CREATE FUNCTION,ALTER ANY MASK,ALTER ANY EXTERNAL DATA SOURCE TO [Role_SchemaDeployer];
GO
--- this won't work as Project won't build ' permission VIEW ANY SENSITIVITY CLASSIFICATION is not valid for object type Database in the targeted platform'
--GRANT VIEW ANY SENSITIVITY CLASSIFICATION,ALTER ANY SENSITIVITY CLASSIFICATION TO [Role_SchemaDeployer];
--GO
--creating role here but definition must go to post script
CREATE ROLE Role_AlterAnyDataspace;
go
CREATE ROLE [mgmt_xtinfra-schema-reader];
GO
GRANT SELECT ON [mgmt_xtinfra].[infra_dist_master] TO [mgmt_xtinfra-schema-reader];
GO
GRANT SELECT ON [mgmt_xtinfra].[infra_mgmt_version_config] TO [mgmt_xtinfra-schema-reader];
GO
CREATE ROLE [Role_SparkConnector]
GO
GRANT ALTER ON SCHEMA::[SqlAnalyticsConnector] TO [Role_SparkConnector];
GO
GRANT CREATE TABLE, ALTER ANY EXTERNAL DATA SOURCE, ALTER ANY EXTERNAL FILE FORMAT TO [Role_SparkConnector];
GO

CREATE ROLE [Role_ActionsExecutor]
GO
GRANT CREATE TABLE, VIEW DATABASE STATE TO [Role_ActionsExecutor];
GO
GRANT SELECT ON SCHEMA::[sys] TO [Role_ActionsExecutor];
GO
GRANT ALTER,EXECUTE,SELECT ON SCHEMA::[Actions] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_trigger_pipeline] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_job_log_execution] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_job_log_execution_details] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_killsession_order_create_or_update] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_user_order_create_or_update] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_user_order_delete] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_workloadclassifier_order_create_or_update] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_workloadclassifier_order_delete] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_workloadgroup_order_create_or_update] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_workloadgroup_order_delete] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_schedule_create] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_schedule_delete] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[InfraValidateCrontabDayOfMonth] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[InfraValidateCrontabDayOfWeek] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[InfraValidateCrontabMonth] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_gatherstats_schedule_create] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_gatherstats_schedule_delete] TO [Role_ActionsExecutor];
GO
GRANT EXECUTE ON OBJECT::[mgmt_xtinfra].[sp_infra_set_config_setting] TO [Role_ActionsExecutor];
GO
GRANT INSERT ON OBJECT::[mgmt_xtinfra].[infra_job_master_v2_details] TO [Role_ActionsExecutor];
GO
GRANT INSERT ON OBJECT::[mgmt_xtinfra].[infra_job_master_v2] TO [Role_ActionsExecutor];
GO
GRANT INSERT ON OBJECT::[mgmt_xtinfra].[infra_orders_details_killsessions] TO [Role_ActionsExecutor];
GO
GRANT INSERT ON OBJECT::[mgmt_xtinfra].[infra_orders_details_users] TO [Role_ActionsExecutor];
GO
GRANT INSERT ON OBJECT::[mgmt_xtinfra].[infra_orders_details_workloadclassifier] TO [Role_ActionsExecutor];
GO
GRANT INSERT ON OBJECT::[mgmt_xtinfra].[infra_orders_details_workloadgroup] TO [Role_ActionsExecutor];
GO
GRANT INSERT ON OBJECT::[mgmt_xtinfra].[infra_orders_master] TO [Role_ActionsExecutor];
GO
GRANT SELECT,DELETE,INSERT ON OBJECT::[mgmt_xtinfra].[infra_schedule] TO [Role_ActionsExecutor];
GO
GRANT SELECT,DELETE,INSERT ON OBJECT::[mgmt_xtinfra].[infra_gatherstats_schedule_detail] TO [Role_ActionsExecutor];
GO
GRANT SELECT ON OBJECT::[mgmt_xtinfra].[infra_global_config] TO [Role_ActionsExecutor];
GO
GRANT SELECT,UPDATE,INSERT ON OBJECT::[mgmt_xtinfra].[infra_config_settings] TO [Role_ActionsExecutor];
GO
GRANT SELECT ON OBJECT::[mgmt_xtinfra].[infra_workspace_identity_config] TO [Role_ActionsExecutor];
GO
GRANT SELECT ON OBJECT::[mgmt_xtinfra].[infra_mgmt_version_config] TO [Role_ActionsExecutor];
GO

-- Create default workload classifier roles
CREATE ROLE [Role_AdhocGroupClassifier];
GO
CREATE ROLE [Role_OtherGroupClassifier];
GO
CREATE ROLE [Role_CriticalGroupClassifier];
GO
CREATE ROLE [Role_RepoGroupClassifier];
GO

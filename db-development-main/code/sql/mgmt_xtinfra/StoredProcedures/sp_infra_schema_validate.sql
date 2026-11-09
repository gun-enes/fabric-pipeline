/*
Description:
This procedure will validate a schema deployment.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_schema_validate] (
	@workspace_name [nvarchar](10),
	@schema_name [nvarchar](32)
) AS
BEGIN
	BEGIN TRY
		DECLARE @log_detail_group uniqueidentifier = NEWID();
		 DECLARE @proc_name nvarchar(128) = 'sp_infra_schema_validate';
		EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
		DECLARE @workspace_schema_name [nvarchar](42) = [mgmt_xtinfra].InfraGetWorkspaceSchemaName(@workspace_name, @schema_name);
		--- add log entry for our job
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'workspace_schema_name', @workspace_schema_name;
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'mode', 'validate';
		EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] 'validate', 0, 9999, @schema_name

		EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'success';
	END TRY
	BEGIN CATCH
		DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
		DECLARE @error_severity INT = ERROR_SEVERITY();
		DECLARE @error_state INT = ERROR_STATE();
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_message', @error_message
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_severity', @error_severity
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_state', @error_state
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'failure';
		--- then throw again to forward error
		THROW;
	END CATCH;

END

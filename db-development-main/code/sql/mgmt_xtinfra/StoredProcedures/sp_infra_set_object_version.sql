/*
Description:
This stored procedure is used to create or update a schema in the database. It should be called by a user with the necessary permissions to create a schema.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_set_object_version] (
	@object_type [nvarchar](128),
	@object_name [nvarchar](256),
	@new_version int
) AS
BEGIN
	DECLARE @log_detail_group uniqueidentifier = NEWID()
	DECLARE @proc_name nvarchar(128) = 'sp_infra_set_object_version';

	BEGIN TRY
		--- add log entry for our job
		EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'new_version', @new_version
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'object_name', @object_name
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'object_type', @object_type

		IF NOT EXISTS (SELECT 1 FROM [mgmt_xtinfra].infra_object_master WHERE type = @object_type AND name = @object_name)
			INSERT INTO [mgmt_xtinfra].infra_object_master (type, name, version) VALUES (@object_type, @object_name, @new_version)
		ELSE
			UPDATE [mgmt_xtinfra].infra_object_master SET version = @new_version WHERE type = @object_type AND name = @object_name

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
GO

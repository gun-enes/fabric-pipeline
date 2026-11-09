/*
Description:
This stored procedure is internally during schema version upgrades. It should not be called directly.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_schema_migrationtask_0003] (
	@mode [nvarchar](32),
	@schema_name [nvarchar](42)
) AS
BEGIN
	-------------------------------
	--- TASK CONFIG STARTS HERE ---
	-------------------------------

	--- use this to easily assign the migration task id for this task
	DECLARE @version_object_type nvarchar(128) = 'schema'
	DECLARE @version_object_name nvarchar(256) = @schema_name
	DECLARE @proc_name nvarchar(128) = 'sp_infra_schema_migrationtask_0003'

	-----------------------------
	--- TASK CONFIG ENDS HERE ---
	-----------------------------

	--- define required variables
	DECLARE @log_detail_group uniqueidentifier = NEWID()
	DECLARE @sql_stmt nvarchar(512)
	--- calc target version
	-- on downgrades we will set the target version to the previous version
	BEGIN TRY
		EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
		DECLARE @migrationtask_id int = [mgmt_xtinfra].InfraGetMigrationTaskId(@proc_name)
		DECLARE @version_object_version int = @migrationtask_id
		IF @mode = 'downgrade'
			SET @version_object_version = @migrationtask_id - 1

		--- assign logging details already here
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'mode', @mode
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'schema_name', @schema_name

		--- validate if we are in the correct version range to apply our change
		DECLARE @can_migrate bit = 0
		EXEC [mgmt_xtinfra].sp_infra_get_migrationtask_canmigrate_object @version_object_type, @version_object_name, @mode, @migrationtask_id, @can_migrate OUTPUT
		IF @can_migrate = 1
		BEGIN
			IF @mode = 'upgrade'
			BEGIN
				PRINT 'Running migration in upgrade mode: ' + @proc_name;

				---------------------------------
				--- UPGRADE LOGIC STARTS HERE ---
				---------------------------------

				--- Create writer
				-- use run directly to avoid nesting of SP calls (limit is 8 :/)
				EXEC [mgmt_xtinfra].sp_infra_schemarole_run_to_version 'upgrade', 0, 9999, @schema_name, 'writer'
				--- Assign permissions
				DECLARE @writer_role_name nvarchar(128) = [mgmt_xtinfra].InfraGetSchemaRoleName(@schema_name, 'writer')
				PRINT 'Assigning schema permissions to schema write role. Schema: ' + @schema_name + ', Role: ' + @writer_role_name;
				SET @sql_stmt = N'GRANT SELECT,ALTER,DELETE,EXECUTE,INSERT,UPDATE,REFERENCES,VIEW DEFINITION ON SCHEMA::' + QUOTENAME(@schema_name) + ' TO ' + QUOTENAME(@writer_role_name) + ';'
				EXEC sp_executesql @sql_stmt;
				PRINT 'Assigning database permissions to schema write role';
				SET @sql_stmt = N'GRANT CREATE PROCEDURE,CREATE TABLE,CREATE FUNCTION,CREATE VIEW TO ' + QUOTENAME(@writer_role_name) + ';'
				EXEC sp_executesql @sql_stmt;

				-------------------------------
				--- UPGRADE LOGIC ENDS HERE ---
				-------------------------------
			END
			ELSE IF @mode = 'downgrade'
			BEGIN
				PRINT 'Running migration in downgrade mode: ' + @proc_name;

				-----------------------------------
				--- DOWNGRADE LOGIC STARTS HERE ---
				-----------------------------------

				-- remove role
				-- use run directly to avoid nesting of SP calls (limit is 8 :/)
				EXEC [mgmt_xtinfra].sp_infra_schemarole_run_to_version 'downgrade', 9999, 0, @schema_name, 'writer'

				---------------------------------
				--- DOWNGRADE LOGIC ENDS HERE ---
				---------------------------------
			END
			ELSE IF @mode = 'validate'
			BEGIN
				PRINT 'Running migration in validate mode: ' + @proc_name;

				------------------------------------
				--- VALIDATION LOGIC STARTS HERE ---
				------------------------------------

				-- validate role
				-- use run directly to avoid nesting of SP calls (limit is 8 :/)
				EXEC [mgmt_xtinfra].sp_infra_schemarole_validate 'validate', 0, 9999, @schema_name, 'writer'

				-- TODO: validate permissions

				----------------------------------
				--- VALIDATION LOGIC ENDS HERE ---
				----------------------------------
			END
			ELSE
				THROW 50000, 'Invalid mode specified for migration task.', 1;

			--- persist object version
			EXEC [mgmt_xtinfra].sp_infra_set_object_version @version_object_type, @version_object_name, @version_object_version
			--- add log entry for our job
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'success';
		END
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
	END CATCH
END

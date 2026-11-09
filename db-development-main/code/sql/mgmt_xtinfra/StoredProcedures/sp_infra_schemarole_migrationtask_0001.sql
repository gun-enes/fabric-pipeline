/*
Description:
This stored procedure is used to create schemaroles based on the schema name. It should be called by a user with the necessary permissions to create roles.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_schemarole_migrationtask_0001] (
	@mode [nvarchar](32),
	@schema_name [nvarchar](42),
	@role_name [nvarchar](48)
) AS
BEGIN
	-------------------------------
	--- TASK CONFIG STARTS HERE ---
	-------------------------------

	--- use this to easily assign the migration task id for this task
	DECLARE @version_object_type nvarchar(128) = 'schemarole'
	DECLARE @version_object_name nvarchar(256) = [mgmt_xtinfra].InfraGetSchemaRoleName(@schema_name, @role_name)
	DECLARE @proc_name nvarchar(128) = 'sp_infra_schemarole_migrationtask_0001'

	--- some shared variables
	DECLARE @combined_name nvarchar(64) = [mgmt_xtinfra].InfraGetSchemaRoleName(@schema_name, @role_name)

	-----------------------------
	--- TASK CONFIG ENDS HERE ---
	-----------------------------

	--- define required variables
	BEGIN TRY
		DECLARE @log_detail_group uniqueidentifier = NEWID()
		DECLARE @sql_stmt nvarchar(512)
		--- assign logging details already here
		EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'mode', @mode
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'schema_name', @schema_name
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'role_name', @role_name

		--- calc target version
		-- on downgrades we will set the target version to the previous version
		DECLARE @migrationtask_id int = [mgmt_xtinfra].InfraGetMigrationTaskId(@proc_name)
		DECLARE @version_object_version int = @migrationtask_id
		IF @mode = 'downgrade'
			SET @version_object_version = @migrationtask_id - 1

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

				--- We need to use QUOTENAME here as it's not possible to use CREATE SCHEMA with parameter binding
				SET @sql_stmt = N'CREATE ROLE ' + QUOTENAME(@combined_name) + ';'

				IF
					NOT EXISTS (
						SELECT 1
						FROM [sys].[database_principals]
						WHERE
							[name] = @combined_name
							AND [type] = 'R'
					)
					BEGIN
						PRINT 'Creating schema role: ' + @combined_name
						EXEC sp_executesql @sql_stmt;
					END
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

				SET @sql_stmt = N'DROP ROLE ' + QUOTENAME(@combined_name) + ';'
				IF EXISTS (
					SELECT 1
					FROM [sys].[database_principals]
					WHERE
						[name] = @combined_name
						AND [type] = 'R'
					)
					BEGIN
						PRINT 'Deleting schema role: ' + @combined_name
						EXEC sp_executesql @sql_stmt;
					END

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

				IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @combined_name AND type = 'R')
					THROW 50000, 'Validation failed. Schemarole does not exist.', 1;

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

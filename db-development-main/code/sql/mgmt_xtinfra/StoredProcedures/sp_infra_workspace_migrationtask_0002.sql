/*
Description:
This stored procedure is internally during schema version upgrades. It should not be called directly.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workspace_migrationtask_0002] (
	@mode [nvarchar](32),
	@workspace_name [nvarchar](10)
) AS
BEGIN
	-------------------------------
	--- TASK CONFIG STARTS HERE ---
	-------------------------------

	--- use this to easily assign the migration task id for this task
	DECLARE @version_object_type nvarchar(128) = 'workspace'
	DECLARE @version_object_name nvarchar(256) = @workspace_name
	DECLARE @proc_name nvarchar(128) = 'sp_infra_workspace_migrationtask_0002'
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(1024);

    -----------------------------
    --- TASK CONFIG ENDS HERE ---
    -----------------------------

    BEGIN TRY
        --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workspace_name', @workspace_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;

		--- calc target version
		-- on downgrades we will set the target version to the previous version
		DECLARE @migrationtask_id int = [mgmt_xtinfra].InfraGetMigrationTaskId(@proc_name)
		DECLARE @version_object_version int = @migrationtask_id
		IF @mode = 'downgrade'
			SET @version_object_version = @migrationtask_id - 1
		-- some custom vars
		DECLARE @role_name nvarchar(128)

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

				--- add schema management SP
				IF OBJECT_ID(QUOTENAME(@workspace_name) + '.[sp_workspace_schema_order_create_or_update]', 'P') IS NULL
				BEGIN
					SET @sql_stmt = N'CREATE PROCEDURE ' + QUOTENAME(@workspace_name) + '.[sp_workspace_schema_order_create_or_update] (@schema_name [nvarchar](32)) AS ' +
								N'EXEC [mgmt_xtinfra].[sp_infra_schema_order_create_or_update] ''' + @workspace_name + ''', @schema_name;'
					EXEC sp_executesql @sql_stmt;
				END

				-- grant exec permission on @sp_name for schema-deployer
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				SET @sql_stmt = N'GRANT EXECUTE ON ' + QUOTENAME(@workspace_name) + '.[sp_workspace_schema_order_create_or_update] TO ' + QUOTENAME(@role_name) + ';'
				EXEC sp_executesql @sql_stmt;

				-- grant insert permissions for schema-deployer
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				SET @sql_stmt = N'GRANT INSERT ON [mgmt_xtinfra].[infra_orders_master] TO ' + QUOTENAME(@role_name) + ';'
				EXEC sp_executesql @sql_stmt;

				-- grant insert permissions for schema-deployer on schema details
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				SET @sql_stmt = N'GRANT INSERT ON [mgmt_xtinfra].[infra_orders_details_schemas] TO ' + QUOTENAME(@role_name) + ';'
				EXEC sp_executesql @sql_stmt;

				-- grant insert permissions for schema-deployer on schemalinks details
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				SET @sql_stmt = N'GRANT INSERT ON [mgmt_xtinfra].[infra_orders_details_schemalinks] TO ' + QUOTENAME(@role_name) + ';'
				EXEC sp_executesql @sql_stmt;

				-- grant insert permissions for schema-deployer on schemaroles details
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				SET @sql_stmt = N'GRANT INSERT ON [mgmt_xtinfra].[infra_orders_details_schemaroles] TO ' + QUOTENAME(@role_name) + ';'
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

				--- drop schema management SP
				IF OBJECT_ID(QUOTENAME(@workspace_name) + '.[sp_workspace_schema_order_create_or_update]', 'P') IS NOT NULL
				BEGIN
					SET @sql_stmt = N'DROP PROCEDURE ' + QUOTENAME(@workspace_name) + '.[sp_workspace_schema_order_create_or_update];'
					EXEC sp_executesql @sql_stmt;
				END

				-- revoke insert permissions for schema-deployer
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				SET @sql_stmt = N'REVOKE INSERT ON [mgmt_xtinfra].[infra_orders_master] FROM ' + QUOTENAME(@role_name) + ';'
				EXEC sp_executesql @sql_stmt;

				-- revoke insert permissions for schema-deployer on schema details
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				SET @sql_stmt = N'REVOKE INSERT ON [mgmt_xtinfra].[infra_orders_details_schemas] FROM ' + QUOTENAME(@role_name) + ';'
				EXEC sp_executesql @sql_stmt;

				-- revoke insert permissions for schema-deployer on schema details
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				SET @sql_stmt = N'REVOKE INSERT ON [mgmt_xtinfra].[infra_orders_details_schemalinks] FROM ' + QUOTENAME(@role_name) + ';'
				EXEC sp_executesql @sql_stmt;

				-- revoke insert permissions for schema-deployer on schema details
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				SET @sql_stmt = N'REVOKE INSERT ON [mgmt_xtinfra].[infra_orders_details_schemaroles] FROM ' + QUOTENAME(@role_name) + ';'
				EXEC sp_executesql @sql_stmt;

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

				--- validate schema management SP
				IF OBJECT_ID(QUOTENAME(@workspace_name) + '.[sp_workspace_schema_order_create_or_update]', 'P') IS NULL
					THROW 50000, 'Schema management SP does not exist.', 1;

				--- validate permissions
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				IF HAS_PERMS_BY_NAME(QUOTENAME(@workspace_name) + '.[sp_workspace_schema_order_create_or_update]', 'OBJECT', 'EXECUTE') = 0
					THROW 50000, 'Schema management SP does not have EXECUTE permission for schema-deployer role.', 1;
				--- order master table
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				IF HAS_PERMS_BY_NAME('[mgmt_xtinfra].[infra_orders_master]', 'OBJECT', 'INSERT') = 0
					THROW 50000, 'Role does not have INSERT permission on [mgmt_xtinfra].[infra_orders_master].', 1;
				--- schema order details table
				SET @role_name = [mgmt_xtinfra].InfraGetSchemaRoleName(@workspace_name, 'deployer');
				IF HAS_PERMS_BY_NAME('[mgmt_xtinfra].[infra_orders_details_schemas]', 'OBJECT', 'INSERT') = 0
					THROW 50000, 'Role does not have INSERT permission on [mgmt_xtinfra].[infra_orders_details_schemas].', 1;

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

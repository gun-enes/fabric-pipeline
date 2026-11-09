/*
Description:
This procedure will place a schema order for deletion.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_schema_order_delete] (
	@workspace_name [nvarchar](10),
	@schema_name [nvarchar](32)
) AS
BEGIN
	DECLARE @requestor nvarchar(128) = SESSION_USER
	DECLARE @order_id uniqueidentifier;
	DECLARE @proc_name nvarchar(128) = 'sp_infra_schema_order_delete'

	BEGIN TRY
		-- log order
		DECLARE @log_detail_group uniqueidentifier = NEWID()
		DECLARE @now DATETIME;
		EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';

		--- add also schemalink deletion orders
		DECLARE @destination_schema_name [nvarchar](42) = [mgmt_xtinfra].InfraGetWorkspaceSchemaName(@workspace_name, @schema_name);

		IF EXISTS(
			SELECT 1
			FROM [sys].[objects]
			WHERE SCHEMA_NAME([schema_id]) = @destination_schema_name
		)
			THROW 50008, 'Schema could not be deleted because it has objects. Drop all VIEW, TABLE, STORED PROCEDURE, FUNCTION, SECURITY POLICY in schema before delete order', 8;

		--- link reader
		SET @order_id = NEWID();
		SET @now = GETDATE(); -- let's hope we're not entering a race condition here with the schema creation itself
		INSERT INTO [mgmt_xtinfra].[infra_orders_master] (id, order_date, requestor, mode, type, status) VALUES (@order_id, @now, @requestor, 'downgrade', 'schemalink', 'new');
		INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemalinks] (order_id, source_schema_name, source_schema_role_name, destination_schema_name, destination_schema_role_name)
		VALUES (@order_id, @workspace_name, 'reader', @destination_schema_name, 'reader');
		--- link writer
		SET @order_id = NEWID();
		SET @now = GETDATE(); -- let's hope we're not entering a race condition here with the schema creation itself
		INSERT INTO [mgmt_xtinfra].[infra_orders_master] (id, order_date, requestor, mode, type, status) VALUES (@order_id, @now, @requestor, 'downgrade', 'schemalink', 'new');
		INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemalinks] (order_id, source_schema_name, source_schema_role_name, destination_schema_name, destination_schema_role_name)
		VALUES (@order_id, @workspace_name, 'writer', @destination_schema_name, 'writer');
		--- link deployer
		SET @order_id = NEWID();
		SET @now = GETDATE(); -- let's hope we're not entering a race condition here with the schema creation itself
		INSERT INTO [mgmt_xtinfra].[infra_orders_master] (id, order_date, requestor, mode, type, status) VALUES (@order_id, @now, @requestor, 'downgrade', 'schemalink', 'new');
		INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemalinks] (order_id, source_schema_name, source_schema_role_name, destination_schema_name, destination_schema_role_name)
		VALUES (@order_id, @workspace_name, 'deployer', @destination_schema_name, 'deployer');

		SET @order_id = NEWID();
		SET @now = GETDATE();
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'order_id', @order_id;
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'order_creation_date', @now;

		-- create order base
		INSERT INTO [mgmt_xtinfra].[infra_orders_master] (id, order_date, requestor, mode, type, status)
		VALUES (@order_id, @now, @requestor, 'downgrade', 'schema', 'new');
		-- attach type specific details
		INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemas] (order_id, workspace_name, schema_name)
		VALUES (@order_id, @workspace_name, @schema_name);

		DECLARE @sql_stmt NVARCHAR(512) = 'EXECUTE [mgmt_xtinfra].[sp_infra_trigger_pipeline] '
			+ QUOTENAME(@workspace_name, '''')
			+ ', ''order_created'';';
		EXECUTE sp_executesql @sql_stmt;

		-- complete log
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
	END CATCH
END

/*
Description:
This procedure will place a schemalink order for creation or update.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_schemalink_order_create_or_update] (
	@source_schema_name [nvarchar](42),
	@source_schema_role_name [nvarchar](48),
	@destination_schema_name [nvarchar](42),
	@destination_schema_role_name [nvarchar](48)
) AS
BEGIN
	DECLARE @requestor nvarchar(128) = SESSION_USER
	DECLARE @order_id uniqueidentifier = NEWID()
	DECLARE @proc_name nvarchar(128) = 'sp_infra_schemalink_order_create_or_update'

	-- log order
	BEGIN TRY
		DECLARE @log_detail_group uniqueidentifier = NEWID()
		DECLARE @now DATETIME = GETDATE();
		EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'order_id', @order_id;
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'order_creation_date', @now;

		-- create order base
		INSERT INTO [mgmt_xtinfra].[infra_orders_master] (id, order_date, requestor, mode, type, status)
		VALUES (@order_id, @now, @requestor, 'upgrade', 'schemalink', 'new');
		-- attach type specific details
		INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemalinks] (order_id, source_schema_name, source_schema_role_name, destination_schema_name, destination_schema_role_name)
		VALUES (@order_id, @source_schema_name, @source_schema_role_name, @destination_schema_name, @destination_schema_role_name);

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

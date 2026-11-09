/*
Description:
This procedure will process all pending orders.

Author:
extern.nachtrub_daniel@allianz.de
Update: Added new order type session
jyothish.b@allianz.com
Date: 30-12-2024
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_process_orders] AS
BEGIN
	--- define required variables
	DECLARE @log_detail_group uniqueidentifier
	DECLARE @proc_name nvarchar(128) = 'sp_infra_process_orders'

	DECLARE @order_id uniqueidentifier
	DECLARE @order_mode [nvarchar](32)
	DECLARE @order_type [nvarchar](32)
	DECLARE @order_status [nvarchar](32)
	DECLARE @version_start int
	DECLARE @version_end int

	-- Invoke the orders processing loop
	WHILE EXISTS (SELECT 1 FROM [mgmt_xtinfra].infra_orders_master WHERE status = 'pending' OR status = 'new')
	BEGIN
		BEGIN TRY
			-- get pending order
			DECLARE @order_requestor [nvarchar](128);
			SELECT TOP 1 @order_id = id, @order_mode = mode, @order_type = type, @order_status = status, @order_requestor = requestor
			FROM [mgmt_xtinfra].infra_orders_master
			WHERE status = 'pending' OR status = 'new'
			ORDER BY order_date ASC;

			-- Reject orders whose requestor is not a member of Role_ActionsExecutor, Role_SchemaDeployer, or dbo.
			IF IS_ROLEMEMBER('Role_ActionsExecutor', @order_requestor) = 0
				AND IS_ROLEMEMBER('Role_SchemaDeployer', @order_requestor) = 0
				AND @order_requestor <> 'dbo'
			BEGIN
				UPDATE [mgmt_xtinfra].infra_orders_master SET status = 'rejected' WHERE id = @order_id;
				PRINT 'Order rejected: requestor ' + ISNULL(@order_requestor, 'NULL') + ' lacks required role membership. id: ' + CAST(@order_id AS nvarchar(36));
			END
			ELSE
			BEGIN

			--- assign logging details already here
			-- adjust log detail per iteration
			SET @log_detail_group = NEWID()
			-- log job details
			EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'order_id', @order_id
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'order_mode', @order_mode
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'order_type', @order_type
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'order_status_before', @order_status
			-- start processing
			PRINT 'Processing order. id: ' + CAST(@order_id AS nvarchar(36));

			--- declare some shared variables
			DECLARE @workspace_name [nvarchar](10);
			DECLARE @schema_name [nvarchar](42);
			DECLARE @role_name [nvarchar](48);
			DECLARE @workspace_schema_name [nvarchar](42);

			--- resolve migration path range depending on the mode
			IF @order_mode = 'upgrade' OR @order_mode = 'validate'
			BEGIN
				SET @version_start = 0;
				SET @version_end = 9999;
			END
			ELSE IF @order_mode = 'downgrade'
			BEGIN
				SET @version_start = 9999;
				SET @version_end = 0;
			END
			ELSE
				THROW 50000, 'Invalid order mode.', 1;

			-- process order based on order type
			IF @order_type = 'workspace'
			BEGIN
				--------------------------------
				--- WORKSPACE ORDER ------------
				--------------------------------
				IF NOT EXISTS (SELECT 1 FROM [mgmt_xtinfra].infra_orders_details_workspaces WHERE order_id = @order_id)
					THROW 50000, 'Order details not found.', 1;

				-- read order details
				SELECT
					@workspace_name = workspace_name
				FROM [mgmt_xtinfra].infra_orders_details_workspaces
				WHERE order_id = @order_id;
				-- execute order
				EXEC [mgmt_xtinfra].[sp_infra_workspace_run_to_version] @order_mode, @version_start, @version_end, @workspace_name;
			END
			ELSE IF @order_type = 'schema'
			BEGIN
				--------------------------------
				--- SCHEMA ORDER ---------------
				--------------------------------

				IF NOT EXISTS (SELECT 1 FROM [mgmt_xtinfra].infra_orders_details_schemas WHERE order_id = @order_id)
					THROW 50000, 'Order details not found.', 1;

				-- read order details
				SELECT
					@workspace_name = workspace_name,
					@schema_name = schema_name
				FROM [mgmt_xtinfra].infra_orders_details_schemas
				WHERE order_id = @order_id;
				-- execute order
				SET @workspace_schema_name = [mgmt_xtinfra].InfraGetWorkspaceSchemaName(@workspace_name, @schema_name);
				EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] @order_mode, @version_start, @version_end, @workspace_schema_name
			END
			ELSE IF @order_type = 'schemarole'
			BEGIN
				--------------------------------
				--- SCHEMAROLE ORDER -----------
				--------------------------------

				IF NOT EXISTS (SELECT 1 FROM [mgmt_xtinfra].infra_orders_details_schemaroles WHERE order_id = @order_id)
					THROW 50000, 'Order details not found.', 1;

				-- read order details
				SELECT
					@workspace_name = workspace_name,
					@schema_name = schema_name,
					@role_name = role_name
				FROM [mgmt_xtinfra].infra_orders_details_schemaroles
				WHERE order_id = @order_id;
				-- execute order
				SET @workspace_schema_name = [mgmt_xtinfra].InfraGetWorkspaceSchemaName(@workspace_name, @schema_name);
				EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] @order_mode, @version_start, @version_end, @workspace_schema_name, @role_name;
			END
			ELSE IF @order_type = 'schemalink'
			BEGIN
				--------------------------------
				--- SCHEMALINK ORDER -----------
				--------------------------------

				IF NOT EXISTS (SELECT 1 FROM [mgmt_xtinfra].infra_orders_details_schemalinks WHERE order_id = @order_id)
					THROW 50000, 'Order details not found.', 1;

				DECLARE @source_schema_name [nvarchar](42);
				DECLARE @source_schema_role_name [nvarchar](48);
				DECLARE @destination_schema_name [nvarchar](42);
				DECLARE @destination_schema_role_name [nvarchar](48);

				-- read order details
				SELECT
					@source_schema_name = source_schema_name,
					@source_schema_role_name = source_schema_role_name,
					@destination_schema_name = destination_schema_name,
					@destination_schema_role_name = destination_schema_role_name
				FROM [mgmt_xtinfra].infra_orders_details_schemalinks
				WHERE order_id = @order_id;
				-- execute order
				EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] @order_mode, @version_start, @version_end, @source_schema_name, @source_schema_role_name, @destination_schema_name, @destination_schema_role_name;
			END
			ELSE IF @order_type = 'rlspolicy'
			BEGIN
				IF NOT EXISTS (
					SELECT 1
					FROM [mgmt_xtinfra].[infra_orders_details_rlspolicy]
					WHERE [order_id] = @order_id
				)
					THROW 50000, 'Order details not found.', 1;

				DECLARE @predicate_function_name [nvarchar](128);
				DECLARE @table_name [nvarchar](78);
				DECLARE @parameter_list [nvarchar](4000);

				-- read order details
				SELECT
					@schema_name = [schema_name],
					@predicate_function_name = [predicate_function_name],
					@table_name = [table_name],
					@parameter_list = [parameter_list]
				FROM [mgmt_xtinfra].[infra_orders_details_rlspolicy]
				WHERE [order_id] = @order_id;

				EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_run_to_version]
					@order_mode,
					@version_start,
					@version_end,
					@schema_name,
					@predicate_function_name,
					@table_name,
					@parameter_list;
			END
			ELSE IF @order_type = 'user'
			BEGIN
				IF NOT EXISTS (
					SELECT 1
					FROM [mgmt_xtinfra].[infra_orders_details_users]
					WHERE [order_id] = @order_id
				)
					THROW 50000, 'Order details not found.', 1;

				DECLARE @user_name [nvarchar](128);


				-- read order details
				SELECT
					@user_name = [user_name]
				FROM [mgmt_xtinfra].[infra_orders_details_users]
				WHERE [order_id] = @order_id;

				EXEC [mgmt_xtinfra].[sp_infra_user_run_to_version]
					@order_mode,
					@version_start,
					@version_end,
					@user_name;
			END
			ELSE IF @order_type = 'killsession'
			BEGIN
				IF NOT EXISTS (
					SELECT 1
					FROM [mgmt_xtinfra].[infra_orders_details_killsessions]
					WHERE [order_id] = @order_id
				)
					THROW 50000, 'Order details not found.', 1;

				DECLARE @session_id [nvarchar](128);

				-- read order details
				SELECT
					@session_id = [session_id]
				FROM [mgmt_xtinfra].[infra_orders_details_killsessions]
				WHERE [order_id] = @order_id;

				EXEC [mgmt_xtinfra].[sp_infra_killsession_run_to_version]
					@order_mode,
					@version_start,
					@version_end,
					@session_id;
			END
			ELSE IF @order_type = 'workloadclassifier'
			BEGIN
				IF NOT EXISTS (
					SELECT 1
					FROM [mgmt_xtinfra].[infra_orders_details_workloadclassifier]
					WHERE [order_id] = @order_id
				)
					THROW 50000, 'Order details not found.', 1;

				DECLARE @classifier_name [nvarchar](128);
				DECLARE	@workload_group [nvarchar](128);
				DECLARE	@member_name [nvarchar](128);
				DECLARE	@wlm_label [nvarchar](255);
				DECLARE	@wlm_context [nvarchar](255);
				DECLARE	@start_time [nvarchar](5);
				DECLARE	@end_time [nvarchar](5);
				DECLARE	@importance_wc [nvarchar](128);

				-- read order details
				SELECT
					@classifier_name = [classifier_name],
					@workload_group = [workload_group],
					@member_name = [member_name],
					@wlm_label = [wlm_label],
					@wlm_context = [wlm_context],
					@start_time = [start_time],
					@end_time = [end_time],
					@importance_wc = [importance]
				FROM [mgmt_xtinfra].[infra_orders_details_workloadclassifier]
				WHERE [order_id] = @order_id;

				EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_run_to_version]
					@order_mode,
					@version_start,
					@version_end,
					@classifier_name,
					@workload_group,
					@member_name,
					@wlm_label,
					@wlm_context,
					@start_time,
					@end_time,
					@importance_wc;
			END
			ELSE IF @order_type = 'workloadgroup'
			BEGIN
				IF NOT EXISTS (
					SELECT 1
					FROM [mgmt_xtinfra].[infra_orders_details_workloadgroup]
					WHERE [order_id] = @order_id
				)
					THROW 50000, 'Order details not found.', 1;

				DECLARE @group_name NVARCHAR(128);
				DECLARE @min_percentage_resource INT;
				DECLARE @cap_percentage_resource INT;
				DECLARE @request_min_resource_grant_percent DECIMAL(5, 2);
				DECLARE @request_max_resource_grant_percent DECIMAL(5, 2);
				DECLARE @importance_wg NVARCHAR(128);
				DECLARE @query_execution_timeout_sec INT

				-- read order details
				SELECT
					@group_name = [group_name],
					@min_percentage_resource = [min_percentage_resource],
					@cap_percentage_resource = [cap_percentage_resource],
					@request_min_resource_grant_percent = [request_min_resource_grant_percent],
					@request_max_resource_grant_percent = [request_max_resource_grant_percent],
					@importance_wg = [importance],
					@query_execution_timeout_sec = [query_execution_timeout_sec]
				FROM [mgmt_xtinfra].[infra_orders_details_workloadgroup]
				WHERE [order_id] = @order_id;

				EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version]
					@order_mode,
					@version_start,
					@version_end,
					@group_name,
					@min_percentage_resource,
					@cap_percentage_resource,
					@request_min_resource_grant_percent,
					@request_max_resource_grant_percent,
					@importance_wg,
					@query_execution_timeout_sec;
			END
			ELSE
				THROW 50000, 'Invalid order type.', 1;

			-- update status
			UPDATE [mgmt_xtinfra].infra_orders_master SET status = 'completed' WHERE id = @order_id;
			--- add log details
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'order_status_after', 'completed'
			--- print status
			PRINT 'Processing order completed successfully. id: ' + CAST(@order_id AS nvarchar(36));
			-- add procedure status
			EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';

			END -- END ELSE (authorized requestor)
		END TRY
		BEGIN CATCH
			-- log error
			UPDATE [mgmt_xtinfra].infra_orders_master SET status = 'failed' WHERE id = @order_id;
			--- add log entry for our job
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'order_status_after', 'failed'
			DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @error_severity INT = ERROR_SEVERITY();
			DECLARE @error_state INT = ERROR_STATE();
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_message', @error_message
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_severity', @error_severity
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_state', @error_state
			EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'failure';
			--- print status
			PRINT 'Error processing order failed. id: ' + CAST(@order_id AS nvarchar(36)) + ', error: ' + @error_message + ', severity: ' + CAST(@error_severity AS nvarchar(10)) + ', state: ' + CAST(@error_state AS nvarchar(10));
		END CATCH
	END
END
GO

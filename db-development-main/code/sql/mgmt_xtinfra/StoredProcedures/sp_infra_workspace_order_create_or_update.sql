/*
Description:
This stored procedure is used to order creation or upgrade of a workspace in the database.
Author:
extern.nachtrub_daniel@allianz.de
Minor change:
Schema size check - 24/10/2024 jyothish.b@allianz.com
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workspace_order_create_or_update] (
    @workspace_name [nvarchar](256)
) AS
BEGIN
    DECLARE @requestor nvarchar(128) = SESSION_USER
    DECLARE @order_id uniqueidentifier = NEWID()
    DECLARE @log_detail_group uniqueidentifier = NEWID()
    DECLARE @proc_name nvarchar(128) = 'sp_infra_workspace_order_create_or_update'
    DECLARE @workspace_name_chk int

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';

        -- workspace name character length check
        SET @workspace_name = TRIM(@workspace_name)
        SET @workspace_name_chk = (SELECT LEN(@workspace_name))
        IF @workspace_name_chk > 10
            BEGIN
            ;
                THROW 400006,
                'Number of Characters in the Workspace name is not in the acceptable range, Number of Characters should be less than or equal to 10',
                1;
            END

        DECLARE @now datetime = GETDATE();
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details
            @log_detail_group, 'order_id', @order_id;
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details
            @log_detail_group, 'order_creation_date', @now;
        -- create order base
        INSERT INTO [mgmt_xtinfra].[infra_orders_master] (
            id, order_date, requestor, mode, type, status
        )
        VALUES (@order_id, @now, @requestor, 'upgrade', 'workspace', 'new');
        -- attach type specific details
        INSERT INTO [mgmt_xtinfra].[infra_orders_details_workspaces] (
            order_id, workspace_name
        )
        VALUES (@order_id, @workspace_name);
        -- complete log
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution
            @log_detail_group, @proc_name, 'success';
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

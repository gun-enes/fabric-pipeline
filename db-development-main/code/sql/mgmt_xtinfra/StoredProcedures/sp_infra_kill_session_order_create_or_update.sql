/*
Description:
This stored procedure is used to kill the session for self service.

Author:
jyothish.b@allianz.com
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_killsession_order_create_or_update] @session_id [nvarchar](128),@workspace_name [nvarchar](10) AS
BEGIN
    DECLARE @requestor nvarchar(128) = SESSION_USER;
    DECLARE @order_id uniqueidentifier = NEWID();
    DECLARE @proc_name nvarchar(128) = 'sp_infra_killsession_order_create_or_update';

    -- log order
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @now datetime = GETDATE();

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'order_id', @order_id;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'order_creation_date', @now;

            -- create order base
        INSERT INTO [mgmt_xtinfra].[infra_orders_master]
        ([id], [order_date], [requestor], [mode], [type], [status])
        VALUES
        (@order_id, @now, @requestor, 'upgrade', 'killsession', 'new');

        -- attach type specific details
        INSERT INTO [mgmt_xtinfra].[infra_orders_details_killsessions]
        (
            [order_id],
            [session_id]
        )
        VALUES
        (
            @order_id,
            @session_id
        );

        DECLARE
            @sql_stmt nvarchar(512) = 'EXECUTE [mgmt_xtinfra].[sp_infra_trigger_pipeline] '
            + QUOTENAME(@workspace_name, '''')
            + ', ''order_created'';';
        EXECUTE sp_executesql @sql_stmt;

        -- complete log
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'success';

    END TRY
    BEGIN CATCH
        --- add log entry for our job
        DECLARE @error_message nvarchar(4000) = ERROR_MESSAGE();
        DECLARE @error_severity int = ERROR_SEVERITY();
        DECLARE @error_state int = ERROR_STATE();

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_message', @error_message;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_severity', @error_severity;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_state', @error_state;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'failure';
        --- then throw again to forward error
        THROW;
    END CATCH
END
GO

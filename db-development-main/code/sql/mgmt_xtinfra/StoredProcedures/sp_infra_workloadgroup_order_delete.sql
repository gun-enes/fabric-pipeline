/*
Description:
Creates order for workload classifier deletion.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_workloadgroup_order_delete]
    @group_name NVARCHAR(128),
    @workspace_name NVARCHAR(10)
AS
BEGIN
    IF @group_name IN ('adhoc_group', 'other_group', 'critical_group', 'repo_group')
            THROW 50000, 'Deleting default workload groups is not allowed. Order can not be created.', 1;

    DECLARE @requestor NVARCHAR(128) = SESSION_USER;
    DECLARE @order_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @proc_name NVARCHAR(128) = 'sp_infra_workloadgroup_order_delete';

    -- log order
    DECLARE @log_detail_group UNIQUEIDENTIFIER = NEWID();
    DECLARE @now DATETIME = GETDATE();

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'group_name', @group_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workspace_name', @workspace_name;

        IF @group_name IS NULL
            THROW 50000, 'Parameter group_name must be provided.', 1;

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'order_id', @order_id;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'order_creation_date', @now;

        -- create order base
        INSERT INTO [mgmt_xtinfra].[infra_orders_master]
        ([id], [order_date], [requestor], [mode], [type], [status])
        VALUES
        (@order_id, @now, @requestor, 'downgrade', 'workloadgroup', 'new');

        -- attach type specific details
        INSERT INTO [mgmt_xtinfra].[infra_orders_details_workloadgroup]
        (
            [order_id],
            [group_name],
            [min_percentage_resource],
            [cap_percentage_resource],
            [request_min_resource_grant_percent],
            [request_max_resource_grant_percent],
            [importance],
            [query_execution_timeout_sec]
        )
        VALUES
        (
            @order_id, @group_name, 0, 0, 0, NULL, NULL, NULL
        );

        DECLARE
            @sql_stmt NVARCHAR(512) = 'EXECUTE [mgmt_xtinfra].[sp_infra_trigger_pipeline] '
            + QUOTENAME(@workspace_name, '''')
            + ', ''order_created'';';
        EXECUTE sp_executesql @sql_stmt;

        -- complete log
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'success';

    END TRY
    BEGIN CATCH
        --- add log entry for our job
        DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @error_severity INT = ERROR_SEVERITY();
        DECLARE @error_state INT = ERROR_STATE();

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

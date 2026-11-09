/*
Description: Creates or an order for Workload Classifier deletion

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_workloadclassifier_order_delete] (
    @classifier_name NVARCHAR(128),
    @workspace_name NVARCHAR(10)
)
AS
BEGIN
    DECLARE @requestor NVARCHAR(128) = SESSION_USER;
    DECLARE @order_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @proc_name NVARCHAR(128) = 'sp_infra_workloadclassifier_order_delete';

    -- log order
    DECLARE @log_detail_group UNIQUEIDENTIFIER = NEWID();
    DECLARE @now DATETIME = GETDATE();

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'classifier_name', @classifier_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workspace_name', @workspace_name;
        IF @classifier_name IS NULL
            THROW 50000, 'Provided classifier_name is NULL. Order can not be created.', 1;

        IF @classifier_name IN ('wc_dbo', 'wc_adhoc_group', 'wc_other_group', 'wc_critical_group', 'wc_repo_group')
            THROW 50000, 'Deleting default workload classifiers is not allowed. Order can not be created.', 1;

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'order_id', @order_id;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'order_creation_date', @now;

        -- create order base
        INSERT INTO [mgmt_xtinfra].[infra_orders_master]
        ([id], [order_date], [requestor], [mode], [type], [status])
        VALUES
        (@order_id, @now, @requestor, 'downgrade', 'workloadclassifier', 'new');

        -- attach type specific details
        INSERT INTO [mgmt_xtinfra].[infra_orders_details_workloadclassifier]
        (
            [order_id],
            [classifier_name],
            [workload_group],
            [member_name],
            [wlm_label],
            [wlm_context],
            [start_time],
            [end_time],
            [importance]
        )
        VALUES
        (@order_id, @classifier_name, '', '', NULL, NULL, NULL, NULL, NULL);

        DECLARE
            @sql_stmt NVARCHAR(512) = 'EXECUTE [mgmt_xtinfra].[sp_infra_trigger_pipeline] '
            + QUOTENAME(@workspace_name, '''')
            + ', ''order_created'';';
        EXECUTE [sp_executesql] @sql_stmt;

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

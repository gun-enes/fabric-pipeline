/*
Description: Creates or an order for Workload Classifier creation or update

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_workloadclassifier_order_create_or_update] (
    @classifier_name NVARCHAR(128),
    @workload_group NVARCHAR(128),
    @member_name NVARCHAR(128),
    @wlm_label NVARCHAR(255),
    @wlm_context NVARCHAR(255),
    @start_hour INT,
    @start_minute INT,
    @end_hour INT,
    @end_minute INT,
    @importance NVARCHAR(128),
    @workspace_name NVARCHAR(10)
)
AS
BEGIN
    DECLARE @requestor NVARCHAR(128) = SESSION_USER;
    DECLARE @order_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @proc_name NVARCHAR(128) = 'sp_infra_workloadclassifier_order_create_or_update';

    -- log order
    DECLARE @log_detail_group UNIQUEIDENTIFIER = NEWID();
    DECLARE @now DATETIME = GETDATE();

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'classifier_name', @classifier_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workload_group', @workload_group;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'member_name', @member_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'wlm_label', @wlm_label;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'wlm_context', @wlm_context;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'start_hour', @start_hour;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'start_minute', @start_minute;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'end_hour', @end_hour;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'end_minute', @end_minute;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'importance', @importance;
        IF @classifier_name IS NULL
            THROW 50000, 'Provided classifier_name is NULL. Order can not be created.', 1;

        IF @workload_group IS NULL OR NOT EXISTS (SELECT 1 FROM [sys].[workload_management_workload_groups] WHERE [name] = @workload_group)
            PRINT('Provided workload_group ' + @workload_group +  ' does not exist. If you did not create a workload group order, this order may fail to create classifier.');

        IF @member_name IS NULL OR NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [name] = @member_name)
            PRINT('Provided member_name ' + @member_name +  ' does not exist. If you did not create a user order, this order may fail to create classifier.');

        IF NOT (
            (@start_hour IS NULL AND @end_hour IS NULL AND @start_minute IS NULL AND @end_minute IS NULL) OR
            (@start_hour IS NOT NULL AND @end_hour IS NOT NULL AND @start_minute IS NOT NULL AND @end_minute IS NOT NULL))
                THROW 50000, 'Parameters start_hour, end_hour, start_minute and end_minute must be all NULL or all provided.', 1;

        IF @start_hour IS NOT NULL AND (@start_hour < 0 OR @start_hour > 23)
            THROW 50000, 'Invalid start_hour parameter. Order can not be created.', 1;

        IF @end_hour IS NOT NULL AND (@end_hour < 0 OR @end_hour > 23)
            THROW 50000, 'Invalid end_hour parameter. Order can not be created.', 1;

        IF @start_minute IS NOT NULL AND (@start_minute < 0 OR @start_minute > 59)
            THROW 50000, 'Invalid start_minute parameter. Order can not be created.', 1;

        IF @end_minute IS NOT NULL AND (@end_minute < 0 OR @end_minute > 59)
            THROW 50000, 'Invalid end_minute parameter. Order can not be created.', 1;

        IF @importance IS NOT NULL AND @importance NOT IN ('HIGH', 'ABOVE_NORMAL', 'NORMAL', 'BELOW_NORMAL', 'LOW')
            THROW 50000, 'Parameter importance must be one of the following values: "HIGH","ABOVE_NORMAL","NORMAL","BELOW_NORMAL","LOW"', 1;

        IF @classifier_name IN ('wc_dbo', 'wc_adhoc_group', 'wc_other_group', 'wc_critical_group', 'wc_repo_group')
            THROW 50000, 'Changing default workload classifiers is not allowed. Order can not be created.', 1;

        DECLARE
            @start_time NVARCHAR(128) = SUBSTRING('0' + CAST(@start_hour AS NVARCHAR(2)), LEN(@start_hour), 2) + ':' + SUBSTRING('0' + CAST(@start_minute AS NVARCHAR(2)), LEN(@start_minute), 2);
        DECLARE
            @end_time NVARCHAR(128) = SUBSTRING('0' + CAST(@end_hour AS NVARCHAR(2)), LEN(@end_hour), 2) + ':' + SUBSTRING('0' + CAST(@end_minute AS NVARCHAR(2)), LEN(@end_minute), 2);

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'order_id', @order_id;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'order_creation_date', @now;

        -- create order base
        INSERT INTO [mgmt_xtinfra].[infra_orders_master]
        ([id], [order_date], [requestor], [mode], [type], [status])
        VALUES
        (@order_id, @now, @requestor, 'upgrade', 'workloadclassifier', 'new');

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
        (
            @order_id,
            @classifier_name,
            @workload_group,
            @member_name,
            @wlm_label,
            @wlm_context,
            @start_time,
            @end_time,
            @importance
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

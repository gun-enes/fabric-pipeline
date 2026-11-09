/*
Description:
Creates order for workload classifier creation.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workloadgroup_order_create_or_update] (
    @group_name NVARCHAR(128),
    @min_percentage_resource INT,
    @cap_percentage_resource INT,
    @request_min_resource_grant_percent DECIMAL(5, 2),
    @request_max_resource_grant_percent DECIMAL(5, 2),
    @importance NVARCHAR(128),
    @query_execution_timeout_sec INT,
    @workspace_name NVARCHAR(10)
)
AS
BEGIN
    DECLARE @requestor NVARCHAR(128) = SESSION_USER;
    DECLARE @order_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @proc_name NVARCHAR(128) = 'sp_infra_workloadgroup_order_create_or_update';
    DECLARE @log_detail_group UNIQUEIDENTIFIER = NEWID();
    DECLARE @now DATETIME = GETDATE();
    DECLARE @msg NVARCHAR(2000);

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'group_name', @group_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workspace_name', @workspace_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'min_percentage_resource', @min_percentage_resource;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'cap_percentage_resource', @cap_percentage_resource;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'request_min_resource_grant_percent', @request_min_resource_grant_percent;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'importance', @importance;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'query_execution_timeout_sec', @query_execution_timeout_sec;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'request_max_resource_grant_percent', @request_max_resource_grant_percent;
        -- Validation of parameters
        IF @group_name IS NULL
        THROW 50000, 'Parameter group_name must be provided.', 1;

        IF @min_percentage_resource IS NULL
            THROW 50000, 'Parameter min_percentage_resource must be provided.', 1;

        IF @cap_percentage_resource IS NULL
            THROW 50000, 'Parameter cap_percentage_resource must be provided.', 1;

        IF @request_min_resource_grant_percent IS NULL
            THROW 50000, 'Parameter request_min_resource_grant_percent must be provided.', 1;

        IF @min_percentage_resource > 100 OR @min_percentage_resource < 0
            THROW 50000, 'Parameter min_percentage_resource must be between 0-100.', 1;

        IF
            (SELECT SUM([min_percentage_resource]) FROM [sys].[workload_management_workload_groups])
            + @min_percentage_resource
            > 100
            PRINT('The total min_percentage_resource sum of existing workload groups exceeds 100 with this request. If you did not have a workload group deletion order, this order may fail to create workload group.');

        IF @min_percentage_resource > @cap_percentage_resource
            THROW 50000, 'Parameter min_percentage_resource must be less than or equal to cap_percentage_resource.', 1;

        IF @cap_percentage_resource > 100 OR @cap_percentage_resource < 1
            THROW 50000, 'Parameter cap_percentage_resource must be between 0-100.', 1;

        IF @request_min_resource_grant_percent > 100 OR @request_min_resource_grant_percent < 0.75
            THROW 50000, 'Parameter request_min_resource_grant_percent must be between 0.75-100.', 1;

        IF @request_min_resource_grant_percent % 0.25 <> 0
            THROW 50000, 'Parameter request_min_resource_grant_percent must be a multiple of 0.25.', 1;

        IF @min_percentage_resource % @request_min_resource_grant_percent <> 0
            THROW 50000, 'Parameter request_min_resource_grant_percent must be a factor of min_percentage_resource.', 1;

        IF @request_min_resource_grant_percent > @cap_percentage_resource
            THROW 50000, 'Parameter request_min_resource_grant_percent must be less than or equal to cap_percentage_resource.', 1;

        IF @request_min_resource_grant_percent > @request_max_resource_grant_percent
            THROW 50000, 'Parameter request_max_resource_grant_percent must be greater than or equal to request_min_resource_grant_percent.', 1;

        IF @query_execution_timeout_sec < 0
            THROW 50000, 'Parameter query_execution_timeout_sec must be equal to or greater than 0.', 1;

        IF @importance NOT IN ('HIGH', 'ABOVE_NORMAL', 'NORMAL', 'BELOW_NORMAL', 'LOW')
            THROW 50000, 'Parameter importance must be one of the following values: "HIGH","ABOVE_NORMAL","NORMAL","BELOW_NORMAL","LOW"', 1;

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'order_id', @order_id;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'order_creation_date', @now;

        -- create order base
        INSERT INTO [mgmt_xtinfra].[infra_orders_master]
        ([id], [order_date], [requestor], [mode], [type], [status])
        VALUES
        (@order_id, @now, @requestor, 'upgrade', 'workloadgroup', 'new');

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
            @order_id,
            @group_name,
            @min_percentage_resource,
            @cap_percentage_resource,
            @request_min_resource_grant_percent,
            @request_max_resource_grant_percent,
            @importance,
            @query_execution_timeout_sec
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

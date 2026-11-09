CREATE PROCEDURE [Actions].[sp_actions_workloadgroup_order_create_or_update]
    @group_name NVARCHAR(128),
    @min_percentage_resource INT,
    @cap_percentage_resource INT,
    @request_min_resource_grant_percent DECIMAL(5, 2),
    @request_max_resource_grant_percent DECIMAL(5, 2),
    @importance NVARCHAR(128),
    @query_execution_timeout_sec INT
AS
BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_order_create_or_update]
        @group_name,
        @min_percentage_resource,
        @cap_percentage_resource,
        @request_min_resource_grant_percent,
        @request_max_resource_grant_percent,
        @importance,
        @query_execution_timeout_sec,
        'Actions';
END

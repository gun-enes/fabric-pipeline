CREATE TABLE [mgmt_xtinfra].[infra_orders_details_workloadgroup]
(
    [order_id] UNIQUEIDENTIFIER NOT NULL,
    [group_name] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [min_percentage_resource] INT NOT NULL,
    [cap_percentage_resource] INT NOT NULL,
    [request_min_resource_grant_percent] DECIMAL(5, 2) NOT NULL,
    [request_max_resource_grant_percent] DECIMAL(5, 2),
    [importance] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
    [query_execution_timeout_sec] INT
) WITH (DISTRIBUTION = REPLICATE);
GO

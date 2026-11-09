CREATE TABLE [mgmt_xtinfra].[infra_orders_details_workspaces]
(
    order_id [uniqueidentifier] NOT NULL,
	workspace_name [nvarchar](10) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL
) WITH ( DISTRIBUTION = ROUND_ROBIN );
GO

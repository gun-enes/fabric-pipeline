CREATE TABLE [mgmt_xtinfra].[infra_orders_details_users]
(
    [order_id] [uniqueidentifier] NOT NULL,
    [user_name] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [created_at] [datetime] NOT NULL
) WITH (DISTRIBUTION = REPLICATE);
GO

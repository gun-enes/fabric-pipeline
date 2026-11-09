CREATE TABLE [mgmt_xtinfra].[infra_orders_details_killsessions]
(
    [order_id] [uniqueidentifier]  NOT NULL,
    [session_id] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL
)
WITH
(
    DISTRIBUTION = REPLICATE,
    CLUSTERED COLUMNSTORE INDEX
)
GO

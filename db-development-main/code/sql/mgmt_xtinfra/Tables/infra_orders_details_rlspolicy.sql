CREATE TABLE [mgmt_xtinfra].[infra_orders_details_rlspolicy]
(
    [order_id] [uniqueidentifier] NOT NULL,
    [schema_name] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [predicate_function_name] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [table_name] [nvarchar](78) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [parameter_list] [nvarchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [created_at] [datetime] NOT NULL
)
WITH
(
    DISTRIBUTION = REPLICATE
)
GO

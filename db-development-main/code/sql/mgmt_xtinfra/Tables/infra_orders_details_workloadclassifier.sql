CREATE TABLE [mgmt_xtinfra].[infra_orders_details_workloadclassifier]
(
    [order_id] [uniqueidentifier] NOT NULL,
    [classifier_name] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [workload_group] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [member_name] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [wlm_label] [nvarchar](255) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [wlm_context] [nvarchar](255) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [start_time] [nvarchar](5) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [end_time] [nvarchar](5) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [importance] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL
)
WITH (DISTRIBUTION = REPLICATE);
GO

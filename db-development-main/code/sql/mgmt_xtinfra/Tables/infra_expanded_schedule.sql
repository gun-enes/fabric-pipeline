CREATE TABLE [mgmt_xtinfra].[infra_expanded_schedule]
(
    [key] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [schedule_action] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [schedule_time] [datetime] NOT NULL,
    [created_at] [datetime] NOT NULL,
    [requestor] [nvarchar](100) NULL
) WITH (DISTRIBUTION = REPLICATE);
GO

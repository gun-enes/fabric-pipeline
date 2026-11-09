CREATE TABLE [mgmt_xtinfra].[infra_schedule]
(
    [key] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [crontab] [nvarchar](305) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [hour] [int] NOT NULL,
    [day_of_month] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [month] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [day_of_week] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [schedule_action] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [priority] [int] NOT NULL,
    [created_at] [datetime] NOT NULL,
    [requestor] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
) WITH (DISTRIBUTION = REPLICATE);
GO

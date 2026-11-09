CREATE TABLE [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
(
	[infra_schedule_key] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[stats_type] [nvarchar](6) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[stats_pct] [INT] NOT NULL,
	[schema_name] [nvarchar](43) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
	[created_at] [datetime] NOT NULL,
	[requestor] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL
)
WITH
(
	DISTRIBUTION = REPLICATE,
	CLUSTERED COLUMNSTORE INDEX
)
GO

CREATE TABLE [mgmt_xtinfra].[infra_partial_restore_master]
(
	[execid] [int]  NULL,
	[session_id] [int]  NULL,
	[exec_user] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[db_name] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[exec_time] [datetime]  NULL,
	[table_schema] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[table_name] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[sectionid] [int]  NULL,
	[filename] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[tab_ext] [varchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[tab_rename] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL
)
WITH
(
	DISTRIBUTION = ROUND_ROBIN,
	CLUSTERED COLUMNSTORE INDEX
)
GO


CREATE TABLE [mgmt_xtinfra].[infra_session_term_master]
(
	[kill_date] [datetime2] NOT NULL,
	[killer_op] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[killer_sid] [nvarchar](32) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[killer_spid] [smallint] NOT NULL,
	[session_id] [nvarchar](32) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[sql_spid] [smallint] NOT NULL,
	[wait_id] [bigint] NOT NULL,
	[type] [nvarchar](255) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[object_type] [nvarchar](255) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[object_name] [nvarchar](386) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[wait_state] [nvarchar](50) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[session_status] [nvarchar](10) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[request_status] [nvarchar](32) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[client_id] [nvarchar](255) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[login_name] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[app_name] [nvarchar](255) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[command] [nvarchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[login_time] [datetime] NOT NULL,
	[request_time] [datetime] NOT NULL
)
WITH ( HEAP ) ;

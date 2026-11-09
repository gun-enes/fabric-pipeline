CREATE TABLE [mgmt_xtinfra].[infra_job_master_v2]
(
    [id] [uniqueidentifier] NOT NULL,
    [date] [datetime] NOT NULL,
    [name] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [status] [varchar](16) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [session_id] [int] NOT NULL,
    [session_user] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL
)
WITH ( DISTRIBUTION = ROUND_ROBIN, CLUSTERED INDEX([id]) );

CREATE TABLE [mgmt_xtinfra].[infra_dr_backup_master]
(
    [execid] [int] NULL,
    [session_id] [int] NULL,
    [exec_user] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [db_name] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [exec_time] [datetime] NULL,
    [table_schema] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [table_name] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [sectionid] [int] NULL,
    [filename] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [dir_name] [varchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [tab_rename] [varchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [source_table_hash] [varbinary](8000) NULL,
    [target_table_hash] [varbinary](8000) NULL,
    [status] [varchar](20) NOT NULL,
    [hash_validation] bit NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
)
GO

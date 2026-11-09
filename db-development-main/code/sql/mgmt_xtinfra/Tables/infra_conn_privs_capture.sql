CREATE TABLE [mgmt_xtinfra].[infra_conn_privs_capture]
(
    [exec_id] [INT] NOT NULL,
    [grant_priv_info] NVARCHAR(500) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
    [revoke_priv_info] NVARCHAR(500) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
    [exec_user] NVARCHAR(20) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
    [exec_time] [DATETIME] NOT NULL
)
WITH (DISTRIBUTION = REPLICATE)
GO

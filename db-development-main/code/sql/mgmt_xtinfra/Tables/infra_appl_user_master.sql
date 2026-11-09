create table [mgmt_xtinfra].[infra_appl_usr_master]
(
    [sid] [int] NOT NULL,
    [created] [datetime]  NOT NULL,
    [user] [varchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [requestor] [varchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [action] [varchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [processed] [datetime] NULL,
    [result] [varchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL
)
WITH
 (
 	DISTRIBUTION = ROUND_ROBIN, CLUSTERED INDEX([sid])
 )
GO;

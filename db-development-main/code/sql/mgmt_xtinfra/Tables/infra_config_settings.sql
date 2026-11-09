CREATE TABLE [mgmt_xtinfra].[infra_config_settings]
(
    [workspace_name] [nvarchar](10) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [name] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [value] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [created_at] [datetime] NOT NULL,
    [modified_at] [datetime] NOT NULL,
    [requestor] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL
)
WITH
(
    DISTRIBUTION = REPLICATE
)
GO

CREATE TABLE [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
(
    [reporting_group_name] [NVARCHAR](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [workspace_name] [NVARCHAR](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [workspace_type] [NVARCHAR](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [type_index] INT NOT NULL
)
WITH (DISTRIBUTION = REPLICATE);
GO

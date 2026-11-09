CREATE TABLE [mgmt_xtinfra].[infra_mgmt_version_config]
(
    [run_id]                   [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [mgmt_deployment_version]  [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [mgmt_deployment_status]   [nvarchar](25)  COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [workspace_name]           [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [app_name]                 [nvarchar](20)  COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [db_name]                  [nvarchar](20)  COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [created_at]               [datetime] NOT NULL,
    [updated_at]               [datetime] NOT NULL
)
WITH (DISTRIBUTION = ROUND_ROBIN, CLUSTERED INDEX ([run_id]));
GO

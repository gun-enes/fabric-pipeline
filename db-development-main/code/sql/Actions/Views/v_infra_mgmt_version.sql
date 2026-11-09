CREATE VIEW [Actions].[v_infra_mgmt_version]
AS
SELECT
    [run_id],
    [mgmt_deployment_version] AS [deployment_version],
    [mgmt_deployment_status]  AS [deployment_status],
    [workspace_name]          AS [mgmt_workspace_name],
    [app_name],
    [db_name],
    [created_at],
    [updated_at]
FROM [mgmt_xtinfra].[infra_mgmt_version_config];
GO

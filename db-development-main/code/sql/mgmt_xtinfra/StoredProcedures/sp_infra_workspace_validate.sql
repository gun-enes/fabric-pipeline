/*
Description:
This procedure will validate a workspace deployment.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workspace_validate] (
	@workspace_name [nvarchar](10),
	@requestor [nvarchar](128)
) AS
BEGIN
	EXEC [mgmt_xtinfra].[sp_infra_workspace_run_to_version] 'validate', 0, 9999, @workspace_name
END

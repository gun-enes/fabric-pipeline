/*
Description:
This procedure will validate a schemarole deployment.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_schemarole_validate] (
	@schema_name [nvarchar](42),
	@role_name [nvarchar](48)
) AS
BEGIN
	EXEC [mgmt_xtinfra].[sp_infra_schemarole_run_to_version] 'validate', 0, 9999, @schema_name, @role_name
END

/*
Description:
This procedure will validate a schemalink deployment.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_schemalink_validate] (
	@source_schema_name [nvarchar](42),
	@source_schema_role_name [nvarchar](48),
	@destination_schema_name [nvarchar](42),
	@destination_schema_role_name [nvarchar](48)
) AS
BEGIN
	EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] 'validate', 0, 9999, @source_schema_name, @source_schema_role_name, @destination_schema_name, @destination_schema_role_name
END

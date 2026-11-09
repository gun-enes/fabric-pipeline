CREATE FUNCTION [mgmt_xtinfra].InfraGetSchemaRoleName (@schema_name nvarchar(40), @role_name nvarchar(16))
RETURNS nvarchar(64)
AS
BEGIN
    RETURN @schema_name + '-schema-' + @role_name
END

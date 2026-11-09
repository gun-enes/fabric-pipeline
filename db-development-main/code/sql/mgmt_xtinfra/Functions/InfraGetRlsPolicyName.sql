CREATE FUNCTION [mgmt_xtinfra].[InfraGetRlsPolicyName] (@schema_name nvarchar(42), @table_name nvarchar(78))
RETURNS nvarchar(128)
AS
BEGIN
    RETURN @schema_name + '-policy-' + @table_name
END

CREATE FUNCTION [mgmt_xtinfra].InfraGetWorkspaceSchemaName (@workspace_name nvarchar(10), @schema_name nvarchar(32))
RETURNS nvarchar(42)
AS
BEGIN
    -- Todo: validate length constraint - return value is max 42 characters long but we could reach 43 according to the inputs
    RETURN @workspace_name + '_' + @schema_name
END

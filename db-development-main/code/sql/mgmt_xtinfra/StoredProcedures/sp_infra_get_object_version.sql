CREATE PROCEDURE [mgmt_xtinfra].sp_infra_get_object_version
    @object_type nvarchar(128),
    @object_name nvarchar(128),
    @version int OUTPUT
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [mgmt_xtinfra].infra_object_master WHERE type = @object_type AND name = @object_name)
    BEGIN
        SET @version = 0
    END
    ELSE
    BEGIN
        SELECT @version = version FROM [mgmt_xtinfra].infra_object_master WHERE type = @object_type AND name = @object_name
    END
END

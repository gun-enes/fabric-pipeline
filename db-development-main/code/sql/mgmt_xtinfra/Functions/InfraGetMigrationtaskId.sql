CREATE FUNCTION [mgmt_xtinfra].InfraGetMigrationTaskId (@migration_task_name nvarchar(128))
RETURNS INT
AS
BEGIN
    RETURN CAST(RIGHT(@migration_task_name, 4) AS INT)
END

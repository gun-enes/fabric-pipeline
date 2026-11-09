CREATE PROCEDURE [UnitTests].[sp_testutil_create_schema]
(
    @workspace NVARCHAR(100),
    @schema NVARCHAR(100)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sql NVARCHAR(MAX),
        @order_id UNIQUEIDENTIFIER,
        @now DATETIME,
        @requestor NVARCHAR(100),
        @destination_schema_name NVARCHAR(42);

    SET @requestor = SESSION_USER;
    SET @now = GETDATE();

    -- Build the full schema name
    SET @destination_schema_name = [mgmt_xtinfra].[InfraGetWorkspaceSchemaName](@workspace, @schema);

    -- Create schema
    EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version]
        @mode = 'upgrade',
        @start_version = 0,
        @end_version = 9999,
        @schema_name = @destination_schema_name;

    -- Create schema links (reader, writer, deployer)
    EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version]
        @mode = 'upgrade',
        @start_version = 0,
        @end_version = 9999,
        @source_schema_name = @workspace,
        @source_schema_role_name = 'reader',
        @destination_schema_name = @destination_schema_name,
        @destination_schema_role_name = 'reader';

    EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version]
        @mode = 'upgrade',
        @start_version = 0,
        @end_version = 9999,
        @source_schema_name = @workspace,
        @source_schema_role_name = 'writer',
        @destination_schema_name = @destination_schema_name,
        @destination_schema_role_name = 'writer';

    EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version]
        @mode = 'upgrade',
        @start_version = 0,
        @end_version = 9999,
        @source_schema_name = @workspace,
        @source_schema_role_name = 'deployer',
        @destination_schema_name = @destination_schema_name,
        @destination_schema_role_name = 'deployer';

    -- Insert schema order
    SET @order_id = NEWID();
    SET @now = GETDATE();

    INSERT INTO [mgmt_xtinfra].[infra_orders_master]
        ([id], [order_date], [requestor], [mode], [type], [status])
    VALUES
        (@order_id, @now, @requestor, 'upgrade', 'schema', 'completed');

    INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemas]
        ([order_id], [workspace_name], [schema_name])
    VALUES
        (@order_id, @workspace, @destination_schema_name);

    -- Insert reader schemalink order
    SET @order_id = NEWID();
    SET @now = GETDATE();
    INSERT INTO [mgmt_xtinfra].[infra_orders_master]
        ([id], [order_date], [requestor], [mode], [type], [status])
    VALUES
        (@order_id, @now, @requestor, 'upgrade', 'schemalink', 'completed');

    INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemalinks]
        ([order_id], [source_schema_name], [source_schema_role_name], [destination_schema_name], [destination_schema_role_name])
    VALUES
        (@order_id, @workspace, 'reader', @destination_schema_name, 'reader');

    -- Insert writer schemalink order
    SET @order_id = NEWID();
    SET @now = GETDATE();
    INSERT INTO [mgmt_xtinfra].[infra_orders_master]
        ([id], [order_date], [requestor], [mode], [type], [status])
    VALUES
        (@order_id, @now, @requestor, 'upgrade', 'schemalink', 'completed');

    INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemalinks]
        ([order_id], [source_schema_name], [source_schema_role_name], [destination_schema_name], [destination_schema_role_name])
    VALUES
        (@order_id, @workspace, 'writer', @destination_schema_name, 'writer');

    -- Insert deployer schemalink order
    SET @order_id = NEWID();
    SET @now = GETDATE();
    INSERT INTO [mgmt_xtinfra].[infra_orders_master]
        ([id], [order_date], [requestor], [mode], [type], [status])
    VALUES
        (@order_id, @now, @requestor, 'upgrade', 'schemalink', 'completed');

    INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemalinks]
        ([order_id], [source_schema_name], [source_schema_role_name], [destination_schema_name], [destination_schema_role_name])
    VALUES
        (@order_id, @workspace, 'deployer', @destination_schema_name, 'deployer');
END;
GO

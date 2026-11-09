CREATE PROCEDURE [UnitTests].[sp_testutil_create_rlspolicy]
(
    @workspace NVARCHAR(100),
    @schema NVARCHAR(100),
    @predicate_function_name NVARCHAR(128),
    @table_name NVARCHAR(78),
    @parameter_list NVARCHAR(4000),
    @admin_group_name NVARCHAR(128)
)
AS
BEGIN

    DECLARE
        @sql NVARCHAR(MAX),
        @order_id UNIQUEIDENTIFIER,
        @now DATETIME,
        @requestor NVARCHAR(100),
        @destination_schema_name NVARCHAR(42),
        @version NVARCHAR(5);

    SET @requestor = SESSION_USER;
    SET @now = GETDATE();
    SET @destination_schema_name = [mgmt_xtinfra].[InfraGetWorkspaceSchemaName](@workspace, @schema);

    -- Create RLS test table if not exists
    SET @sql = N'
    IF OBJECT_ID(QUOTENAME(@schema_name) + ''.'' + QUOTENAME(@table_name), ''U'') IS NULL
    BEGIN
        DECLARE @create NVARCHAR(MAX);
        SET @create = N''CREATE TABLE '' + QUOTENAME(@schema_name) + ''.'' + QUOTENAME(@table_name) +
                      N''([aad_security_group_name] NVARCHAR(128), [private_info] NVARCHAR(50));'';
        EXEC sp_executesql @create;
    END;';
    EXEC [sp_executesql] @sql,
        N'@schema_name NVARCHAR(100), @table_name NVARCHAR(78)',
        @schema_name = @destination_schema_name,
        @table_name = @table_name;

    -- Populate RLS test table with example data
    SET @sql = N'
    IF NOT EXISTS (
        SELECT 1 FROM ' + QUOTENAME(@destination_schema_name) + '.' + QUOTENAME(@table_name) + '
        WHERE [aad_security_group_name] = @group AND [private_info] = @info
    )
    INSERT INTO ' + QUOTENAME(@destination_schema_name) + '.' + QUOTENAME(@table_name) + '
        ([aad_security_group_name], [private_info])
    VALUES (@group, @info);';
    EXEC [sp_executesql] @sql,
        N'@group NVARCHAR(128), @info NVARCHAR(50)',
        @group = @admin_group_name,
        @info  = 'admin group private';

    -- Create RLS predicate function if not exists
    SET @sql = N'
    IF OBJECT_ID(' + QUOTENAME(QUOTENAME(@destination_schema_name) + '.' + QUOTENAME(@predicate_function_name), '''') + ', ''IF'') IS NULL
    BEGIN
        DECLARE @func NVARCHAR(MAX);
        SET @func = N''CREATE FUNCTION '' + QUOTENAME(@schema_name) + ''.'' + QUOTENAME(@func_name) +
                    N''(@aad_security_group_name NVARCHAR(128))
                    RETURNS TABLE WITH SCHEMABINDING AS
                    RETURN (SELECT IS_MEMBER(@aad_security_group_name) AS predicate_result);'';
        EXEC sp_executesql @func;
    END;';
    EXEC [sp_executesql] @sql,
        N'@schema_name NVARCHAR(100), @func_name NVARCHAR(128)',
        @schema_name = @destination_schema_name,
        @func_name = @predicate_function_name;

    -- Execute RLS policy creation or update using run-to-version logic
    EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_run_to_version]
        @mode = 'upgrade',
        @start_version = 0,
        @end_version = 9999,
        @schema_name = @destination_schema_name,
        @predicate_function_name = @predicate_function_name,
        @table_name = @table_name,
        @parameter_list = @parameter_list;

    -- Insert completed RLS policy order entries
    SET @order_id = NEWID();
    SET @now = GETDATE();

    INSERT INTO [mgmt_xtinfra].[infra_orders_master]
        ([id], [order_date], [requestor], [mode], [type], [status])
    VALUES
        (@order_id, @now, @requestor, 'upgrade', 'rlspolicy', 'completed');

    INSERT INTO [mgmt_xtinfra].[infra_orders_details_rlspolicy]
        ([order_id], [schema_name], [predicate_function_name], [table_name], [parameter_list], [created_at])
    VALUES
        (@order_id, @destination_schema_name, @predicate_function_name, @table_name, @parameter_list, @now);
END;
GO

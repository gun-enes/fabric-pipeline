CREATE PROCEDURE [UnitTests].[sp_testutil_verify_rlspolicy]
(
    @workspace NVARCHAR(100),
    @schema NVARCHAR(100),
    @table_name NVARCHAR(78)
)
AS
BEGIN

    DECLARE @destination_schema_name NVARCHAR(42) = [mgmt_xtinfra].[InfraGetWorkspaceSchemaName](@workspace, @schema);
    DECLARE @combined_policy_name NVARCHAR(128) = [mgmt_xtinfra].[InfraGetRlsPolicyName](@destination_schema_name, @table_name);
    DECLARE @version NVARCHAR(5);

    PRINT('Verifying RLS policy downgrade and deletion for workspace: ' + @workspace);

    -- Verify created [rlspolicy] is downgraded in object master table
    EXEC [mgmt_xtinfra].[sp_infra_get_object_version]
        @object_type = 'rlspolicy',
        @object_name = @combined_policy_name,
        @version = @version OUTPUT;
    IF @version <> '0'
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('RLS policy version is not downgraded to 0 for:', @combined_policy_name);
    END;

    -- Verify [rlspolicy] is removed
    DECLARE @remaining_policies NVARCHAR(MAX);
    SELECT @remaining_policies = STRING_AGG([sp].[name], ', ')
    FROM [sys].[security_policies] AS [sp]
    INNER JOIN [sys].[schemas] AS [s]
        ON [sp].[schema_id] = [s].[schema_id]
    WHERE [sp].[name] = @combined_policy_name
      AND [s].[name] = @destination_schema_name;

    IF @remaining_policies IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected RLS policies found:', @remaining_policies);
    END;

    PRINT('RLS Policy deletion verification completed for workspace: ' + @workspace);
END
GO

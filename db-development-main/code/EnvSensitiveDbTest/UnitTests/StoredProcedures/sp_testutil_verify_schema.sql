CREATE PROCEDURE [UnitTests].[sp_testutil_verify_schema]
(
    @workspace NVARCHAR(100),
    @schema NVARCHAR(78)
)
AS
BEGIN

    DECLARE
        @destination_schema_name NVARCHAR(42),
        @combined_source_name NVARCHAR(64),
        @combined_destination_name NVARCHAR(64),
        @schema_link_object_name NVARCHAR(256),
        @remaining NVARCHAR(MAX),
        @version INT;

    -- Build the full schema name
    SET @destination_schema_name = [mgmt_xtinfra].[InfraGetWorkspaceSchemaName](@workspace, @schema);

    -- Verify test schema is removed
    SELECT @remaining = [name]
    FROM [sys].[schemas]
    WHERE [name] = @destination_schema_name;
    IF @remaining IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected schema found:', @remaining);
    END;

    -- Verify test schema version is set to 0 in [infra_object_master]
    EXEC [mgmt_xtinfra].[sp_infra_get_object_version]
        @object_type = 'schema',
        @object_name = @destination_schema_name,
        @version = @version OUTPUT;
    IF @version <> 0
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Schema version is not downgraded to 0 for:', @destination_schema_name);
    END;

    SET @combined_destination_name = [mgmt_xtinfra].[InfraGetSchemaRoleName](@destination_schema_name, 'reader');
    SET @combined_source_name = [mgmt_xtinfra].[InfraGetSchemaRoleName](@workspace, 'reader');
    SET @schema_link_object_name = @combined_source_name + '_to_' + @combined_destination_name;

    -- Verify schema role (reader) is removed
    SELECT @remaining = [name]
    FROM [sys].[database_principals]
    WHERE [name] = @combined_destination_name AND [type] = 'R';
    IF @remaining IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected schema role (reader) found:', @remaining);
    END;

    -- Verify schema role (reader) version is set to 0 in [infra_object_master]
    EXEC [mgmt_xtinfra].[sp_infra_get_object_version]
        @object_type = 'schemarole',
        @object_name = @combined_destination_name,
        @version = @version OUTPUT;
    IF @version <> 0
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Reader schema role version not downgraded to 0:', @combined_destination_name);
    END;

    -- Verify schema link (reader) is removed
    SELECT TOP 1 @remaining = [rp].[name] + '→' + [mp].[name]
    FROM [sys].[database_role_members] AS [drm]
    LEFT JOIN [sys].[database_principals] AS [rp] ON [drm].[role_principal_id] = [rp].[principal_id]
    LEFT JOIN [sys].[database_principals] AS [mp] ON [drm].[member_principal_id] = [mp].[principal_id]
    WHERE [rp].[type] = 'R' AND [mp].[type] = 'R'
      AND [rp].[name] = @combined_destination_name
      AND [mp].[name] = @combined_source_name;
    IF @remaining IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected schema link (reader) found:', @remaining);
    END;

    -- Verify schema link (reader) version is set to 0 in [infra_object_master]
    EXEC [mgmt_xtinfra].[sp_infra_get_object_version]
        @object_type = 'schemalink',
        @object_name = @schema_link_object_name,
        @version = @version OUTPUT;
    IF @version <> 0
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Reader schema link version not downgraded to 0:', @schema_link_object_name);
    END;

    SET @combined_destination_name = [mgmt_xtinfra].[InfraGetSchemaRoleName](@destination_schema_name, 'writer');
    SET @combined_source_name = [mgmt_xtinfra].[InfraGetSchemaRoleName](@workspace, 'writer');
    SET @schema_link_object_name = @combined_source_name + '_to_' + @combined_destination_name;

    -- Verify schema role (writer) is removed
    SELECT @remaining = [name]
    FROM [sys].[database_principals]
    WHERE [name] = @combined_destination_name AND [type] = 'R';
    IF @remaining IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected schema role (writer) found:', @remaining);
    END;

    -- Verify schema role (writer) version is set to 0 in [infra_object_master]
    EXEC [mgmt_xtinfra].[sp_infra_get_object_version]
        @object_type = 'schemarole',
        @object_name = @combined_destination_name,
        @version = @version OUTPUT;
    IF @version <> 0
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Writer schema role version not downgraded to 0:', @combined_destination_name);
    END;

    -- Verify schema link (writer) is removed
    SELECT TOP 1 @remaining = [rp].[name] + '→' + [mp].[name]
    FROM [sys].[database_role_members] AS [drm]
    LEFT JOIN [sys].[database_principals] AS [rp] ON [drm].[role_principal_id] = [rp].[principal_id]
    LEFT JOIN [sys].[database_principals] AS [mp] ON [drm].[member_principal_id] = [mp].[principal_id]
    WHERE [rp].[type] = 'R' AND [mp].[type] = 'R'
      AND [rp].[name] = @combined_destination_name
      AND [mp].[name] = @combined_source_name;
    IF @remaining IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected schema link (writer) found:', @remaining);
    END;

    -- Verify schema link (writer) version is set to 0 in [infra_object_master]
    EXEC [mgmt_xtinfra].[sp_infra_get_object_version]
        @object_type = 'schemalink',
        @object_name = @schema_link_object_name,
        @version = @version OUTPUT;
    IF @version <> 0
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Writer schema link version not downgraded to 0:', @schema_link_object_name);
    END;

    SET @combined_destination_name = [mgmt_xtinfra].[InfraGetSchemaRoleName](@destination_schema_name, 'deployer');
    SET @combined_source_name = [mgmt_xtinfra].[InfraGetSchemaRoleName](@workspace, 'deployer');
    SET @schema_link_object_name = @combined_source_name + '_to_' + @combined_destination_name;

    -- Verify schema role (deployer) is removed
    SELECT @remaining = [name]
    FROM [sys].[database_principals]
    WHERE [name] = @combined_destination_name AND [type] = 'R';
    IF @remaining IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected schema role (deployer) found:', @remaining);
    END;

    -- Verify schema role (deployer) version is set to 0 in [infra_object_master]
    EXEC [mgmt_xtinfra].[sp_infra_get_object_version]
        @object_type = 'schemarole',
        @object_name = @combined_destination_name,
        @version = @version OUTPUT;
    IF @version <> 0
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Deployer schema role version not downgraded to 0:', @combined_destination_name);
    END;

    -- Verify schema link (deployer) is removed
    SELECT TOP 1 @remaining = [rp].[name] + '→' + [mp].[name]
    FROM [sys].[database_role_members] AS [drm]
    LEFT JOIN [sys].[database_principals] AS [rp] ON [drm].[role_principal_id] = [rp].[principal_id]
    LEFT JOIN [sys].[database_principals] AS [mp] ON [drm].[member_principal_id] = [mp].[principal_id]
    WHERE [rp].[type] = 'R' AND [mp].[type] = 'R'
      AND [rp].[name] = @combined_destination_name
      AND [mp].[name] = @combined_source_name;
    IF @remaining IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected schema link (deployer) found:', @remaining);
    END;

    -- Verify schema link (deployer) version is set to 0 in [infra_object_master]
    EXEC [mgmt_xtinfra].[sp_infra_get_object_version]
        @object_type = 'schemalink',
        @object_name = @schema_link_object_name,
        @version = @version OUTPUT;
    IF @version <> 0
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Deployer schema link version not downgraded to 0:', @schema_link_object_name);
    END;

    PRINT('Schema roles/links (reader, writer, deployer) verification completed for workspace: ' + @workspace);
END
GO

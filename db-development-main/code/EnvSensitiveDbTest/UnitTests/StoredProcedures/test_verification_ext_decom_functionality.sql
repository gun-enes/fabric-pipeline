-- Assertion phase of the extension decommission functionality
CREATE PROCEDURE [UnitTests].[test_verification_ext_decom_functionality]
AS
BEGIN
    PRINT ('Executing Assertion Phase');

    -- Test variables
    DECLARE
        @test_workspace NVARCHAR(20),
        @test_schema NVARCHAR(20),
        @test_rlspolicy_table NVARCHAR(20),
        @is_spf NVARCHAR(2),

        @destination_schema_name NVARCHAR(20),
        @version NVARCHAR(5),
        @sql NVARCHAR(MAX),
        @count_check INT;

    -- Set test variables
    SELECT
        @test_workspace = MAX(CASE WHEN [KeyName] = 'test_workspace' THEN [Value] END),
        @test_schema = MAX(CASE WHEN [KeyName] = 'test_schema' THEN [Value] END),
        @test_rlspolicy_table = MAX(CASE WHEN [KeyName] = 'test_rlspolicy_table' THEN [Value] END),
        @is_spf = MAX(CASE WHEN [KeyName] = 'is_spf' THEN [Value] END)
    FROM [UnitTests].[KeyValueStore];

    SET @destination_schema_name = [mgmt_xtinfra].[InfraGetWorkspaceSchemaName](@test_workspace, @test_schema);

    PRINT 'Verifying that test workspace is removed...';
    DECLARE @schema NVARCHAR(100);
    SELECT @schema = [name]
    FROM [sys].[schemas]
    WHERE [name] = @test_workspace;
    IF @schema IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected schema found: ', @schema);
    END;

    PRINT 'Verifying that workspace version is set to 0 in [infra_object_master]...';
    EXEC [mgmt_xtinfra].[sp_infra_get_object_version]
        @object_type = 'workspace',
        @object_name = @test_workspace,
        @version = @version OUTPUT;
    IF @version <> '0'
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Workspace version is not downgraded to 0 for: ', @test_workspace);
    END;

    PRINT 'Verifying created schema is downgraded...';
    EXEC [UnitTests].[sp_testutil_verify_schema] @test_workspace, @test_schema;

    PRINT 'Verifying workspace/schema procedure removal...';
    DECLARE @procs NVARCHAR(MAX);
    SELECT @procs = STRING_AGG([s].[name] + '.' + [p].[name], ', ')
    FROM [sys].[procedures] AS [p]
    JOIN [sys].[schemas] AS [s] ON [p].[schema_id] = [s].[schema_id]
    WHERE [s].[name] IN (@test_workspace, @destination_schema_name);
    IF @procs IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected procedures found: ', @procs);
    END;

    PRINT 'Verifying workspace/schema function removal...';
    DECLARE @funcs NVARCHAR(MAX);
    SELECT @funcs = STRING_AGG([s].[name] + '.' + [o].[name], ', ')
    FROM [sys].[objects] AS [o]
    JOIN [sys].[schemas] AS [s] ON [o].[schema_id] = [s].[schema_id]
    WHERE [s].[name] IN (@test_workspace, @destination_schema_name)
    AND [o].[type] IN ('FN', 'IF', 'TF');
    IF @funcs IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected functions found: ', @funcs);
    END;

    PRINT 'Verifying workspace/schema view removal...';
    DECLARE @views NVARCHAR(MAX);
    SELECT @views = STRING_AGG([s].[name] + '.' + [v].[name], ', ')
    FROM [sys].[views] AS [v]
    JOIN [sys].[schemas] AS [s] ON [v].[schema_id] = [s].[schema_id]
    WHERE [s].[name] IN (@test_workspace, @destination_schema_name);
    IF @views IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected views found: ', @views);
    END;

    PRINT 'Verifying workspace/schema table removal...';
    DECLARE @tables NVARCHAR(MAX);
    SELECT @tables = STRING_AGG([s].[name] + '.' + [t].[name], ', ')
    FROM [sys].[tables] AS [t]
    JOIN [sys].[schemas] AS [s] ON [t].[schema_id] = [s].[schema_id]
    WHERE [s].[name] IN (@test_workspace, @destination_schema_name);
    IF @tables IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected tables found: ', @tables);
    END;

    -- SPF specific verifications
    IF @is_spf = '1'
    BEGIN
        -- Verify the static schemas for SPF are removed
        SET @sql =
        (
            SELECT STRING_AGG(CAST('EXEC [UnitTests].[sp_testutil_verify_schema] ''tsqltest'', ''' + [s].[schema_name] + '''; ' AS NVARCHAR(MAX)), '')
            FROM [mgmt_xtinfra].[infra_static_ext_schemas] AS [s]
        );
        EXEC [sp_executesql] @sql;

        PRINT 'Verifying SPF reporting group users removal...';
        DECLARE @spf_groups NVARCHAR(MAX);
        SELECT @spf_groups = STRING_AGG([dp].[name], ', ')
        FROM [sys].[database_principals] AS [dp]
        JOIN [mgmt_xtinfra].[infra_workspace_reporting_groups_config] AS [rg]
            ON [dp].[name] = [rg].[reporting_group_name]
        WHERE [rg].[workspace_name] = @test_workspace;
        IF @spf_groups IS NOT NULL
        BEGIN
            INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
            VALUES ('Unexpected SPF reporting group users found: ', @spf_groups);
        END;
    END;

    IF EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = 'runtime_mode' AND [value] = 'ADP'
    )
    BEGIN
        PRINT 'Verifying ADP reporting group users are not removed...';
        SELECT @count_check = COUNT(*)
        FROM [sys].[database_principals] AS [dp]
        JOIN [mgmt_xtinfra].[infra_workspace_reporting_groups_config] AS [rg]
            ON [dp].[name] = [rg].[reporting_group_name]
        WHERE [rg].[workspace_name] = @test_workspace;
        IF @count_check = 0
        BEGIN
            INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
            VALUES ('No ADP reporting group users found for workspace: ', @test_workspace);
        END;
    END;

    PRINT 'Verifying workspace users removal...';
    DECLARE @workspace_users NVARCHAR(MAX);
    SELECT @workspace_users = STRING_AGG([dp].[name], ', ')
    FROM [sys].[database_principals] AS [dp]
    JOIN (
        SELECT [workspace_name], [group_name]
        FROM [mgmt_xtinfra].[infra_workspace_identity_config]
        UNPIVOT (
            [group_name] FOR [group_name_type] IN (
                [admin_group_name],
                [contributor_group_name],
                [reader_group_name],
                [service_principal_name],
                [synapse_workspace_msi_name],
                [actions_group_name]
            )
        ) AS [unpvt]
    ) AS [unpvt_identity_config]
        ON [dp].[name] = [unpvt_identity_config].[group_name]
    WHERE [unpvt_identity_config].[workspace_name] = @test_workspace;
    IF @workspace_users IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected workspace users found: ', @workspace_users);
    END;

    PRINT 'Verifying extension-specific roles removal...';
    DECLARE @roles NVARCHAR(MAX);
    SELECT @roles = STRING_AGG([name], ', ')
    FROM [sys].[database_principals]
    WHERE [type] = 'R'
    AND [name] LIKE @destination_schema_name + '-%';
    IF @roles IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected extension-specific roles found: ', @roles);
    END;

    PRINT 'Verifying core members removal from workspace schema roles...';
    DECLARE @core_members NVARCHAR(MAX);
    SELECT @core_members = STRING_AGG([r].[name] + ':' + [p].[name], ', ')
    FROM [sys].[database_role_members] AS [m]
    INNER JOIN [sys].[database_principals] AS [r] ON [m].[role_principal_id] = [r].[principal_id]
    INNER JOIN [sys].[database_principals] AS [p] ON [m].[member_principal_id] = [p].[principal_id]
    WHERE [r].[name] IN (
        @test_workspace + '-schema-reader',
        @test_workspace + '-schema-writer',
        @test_workspace + '-schema-deployer'
    );
    IF @core_members IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected core members in schema roles: ', @core_members);
    END;

    PRINT 'Verifying removal of opt-out self-service component...';
    DECLARE @config_rows NVARCHAR(MAX);
    SELECT @config_rows = STRING_AGG(CONVERT(NVARCHAR(200), [workspace_name]), ', ')
    FROM [mgmt_xtinfra].[infra_config_settings]
    WHERE [workspace_name] = @test_workspace;
    IF @config_rows IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected opt-out self-service rows found for workspace: ', @config_rows);
    END;

    PRINT 'Verifying removal of test gatherstats schedule...';
    EXEC [UnitTests].[sp_testutil_verify_gatherstats_schedule] @test_workspace;

    PRINT 'Verifying RLS policy deletion...';
    EXEC [UnitTests].[sp_testutil_verify_rlspolicy] @test_workspace, @test_schema, @test_rlspolicy_table;
END
GO;

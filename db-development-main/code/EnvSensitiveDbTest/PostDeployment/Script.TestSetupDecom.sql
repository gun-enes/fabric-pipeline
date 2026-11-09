BEGIN
    PRINT 'Starting decommission test setup';

    INSERT INTO [UnitTests].[TestStatus]
    VALUES ('test_verification_ext_decom_functionality', '', @now, '');

    -- Arrange
    DECLARE @test_workspace NVARCHAR(20) = 'tsqltest';
    DECLARE @test_schema NVARCHAR(20) = 'test_schema';
    DECLARE @test_schedule_key NVARCHAR(20) = 'decom_test_gatherstats';
    DECLARE @destination_schema_name NVARCHAR(50);
    DECLARE @test_rlspolicy_table NVARCHAR(20) = 'rls_test_table';
    DECLARE @test_table NVARCHAR(20) = 'test_table'
    DECLARE @test_function NVARCHAR(20) = 'test_function';
    DECLARE @test_view NVARCHAR(20) = 'test_view';
    DECLARE @test_procedure NVARCHAR(20) = 'test_procedure';
    DECLARE @test_admin_group_name NVARCHAR(100) = 'Data Platform-ADP-TDP-DMP-0002-TST-admin-mgmt';
    DECLARE @test_contributor_group_name NVARCHAR(100) = 'Data Platform-ADP-TDP-DMP-0002-TST-contributor-mgmt';
    DECLARE @test_operations_group_name NVARCHAR(100) = 'Data Platform-ADP-TDP-DMP-0002-TST-operations-mgmt';
    DECLARE @test_reader_group_name NVARCHAR(100) = 'Data Platform-ADP-TDP-DMP-0002-TST-reader-mgmt';
    DECLARE @test_service_principal_name NVARCHAR(100) = 'az_adp_tdp_dmp_0002_tst_synapse_deploy';
    DECLARE @test_synapse_workspace_msi_name NVARCHAR(100) = 'synw-tdp-0002-tst-mgmt';
    DECLARE @test_reporting_group_name NVARCHAR(100) = 'Data Platform-ADP-TDP-DMP-0001-TST-reader-mgmt';
    DECLARE @test_actions_group_name NVARCHAR(5) = '';
    DECLARE @is_spf NVARCHAR(2);
    DECLARE @sql NVARCHAR(MAX);

    BEGIN TRY
        SELECT
            @is_spf
            = CASE
                WHEN
                    EXISTS (
                        SELECT 1
                        FROM [mgmt_xtinfra].[infra_global_config]
                        WHERE
                            [key] = 'runtime_mode'
                            AND [value] = 'SPF'
                    )
                    THEN '1'
                ELSE '0'
            END;

        -- Insert test variables
        INSERT INTO [UnitTests].[KeyValueStore] ([KeyName], [Value])
        VALUES ('test_workspace', @test_workspace);

        INSERT INTO [UnitTests].[KeyValueStore] ([KeyName], [Value])
        VALUES ('test_schema', @test_schema);

        INSERT INTO [UnitTests].[KeyValueStore] ([KeyName], [Value])
        VALUES ('test_rlspolicy_table', @test_rlspolicy_table);

        INSERT INTO [UnitTests].[KeyValueStore] ([KeyName], [Value])
        VALUES ('is_spf', @is_spf);

        -- Setup test workspace identity config
        INSERT INTO [mgmt_xtinfra].[infra_workspace_identity_config]
        (
            workspace_name, workspace_type, admin_group_name, contributor_group_name,
            operations_group_name, reader_group_name, service_principal_name,
            synapse_workspace_msi_name, actions_group_name, type_index
        )
        VALUES
        (
            @test_workspace, 'extension',
            @test_admin_group_name,
            @test_contributor_group_name,
            @test_operations_group_name,
            @test_reader_group_name,
            @test_service_principal_name,
            @test_synapse_workspace_msi_name,
            @test_actions_group_name,
            1
        );

        -- Setup test infra_workspace_reporting_groups_config
        INSERT INTO [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
        (reporting_group_name, workspace_name, workspace_type, type_index)
        VALUES
        (
            @test_reporting_group_name,
            @test_workspace,
            'extension',
            1
        );

        -- Create test workspace
        PRINT 'Creating workspace: tsqltest';
        EXEC [mgmt_xtinfra].[sp_infra_workspace_run_to_version]
            @mode = 'upgrade',
            @start_version = 0,
            @end_version = 9999,
            @workspace_name = @test_workspace;

        -- Create static schema
        IF @is_spf = '1'
            BEGIN
                EXEC [mgmt_xtinfra].[sp_testutil_spf_create_static_schemas];
            END;

        -- Extension user role assignments
        PRINT 'Extension user role assignments';
        EXEC [mgmt_xtinfra].[sp_infra_ext_user_role_assignments]
            @ext_name = @test_workspace;

        IF @is_spf = '1'
            BEGIN
                EXEC [mgmt_xtinfra].[sp_infra_ext_spf_user_role_assignments]
                    @ext_name = @test_workspace;
            END;

        SET @destination_schema_name = [mgmt_xtinfra].InfraGetWorkspaceSchemaName(@test_workspace, @test_schema);

        -- Simulate customer orders
        -- Create new schema
        PRINT 'Creating schema: ' + @test_schema;
        EXEC [UnitTests].[sp_testutil_create_schema] @workspace = @test_workspace, @schema = @test_schema;

        -- Create a new statistics schedule
        PRINT 'Creating new statistics schedule: ' + @test_schedule_key;
        EXEC [UnitTests].[sp_testutil_create_gatherstats_schedule]
            @key = @test_schedule_key,
            @hour = 8,
            @day_of_month = '*',
            @month = '*',
            @day_of_week = '*',
            @priority = 100,
            @stats_type = 'SCHEMA',
            @stats_pct = 20,
            @schema = @destination_schema_name;

        -- Create RLS policy
        PRINT 'Creating new RLS policy';
        EXEC [UnitTests].[sp_testutil_create_rlspolicy]
            @workspace = @test_workspace,
            @schema = @test_schema,
            @predicate_function_name = 'rls_test_predicate_function',
            @table_name = @test_rlspolicy_table,
            @parameter_list = '["aad_security_group_name"]',
            @admin_group_name = @test_admin_group_name;

        -- Set optout enabled/disabled config setting
        EXEC [mgmt_xtinfra].[sp_infra_set_config_setting]
            @config_workspace_name = @test_workspace,
            @name = 'on-pause-pipeline-wait-opt-out',
            @value = 'enabled',
            @workspace_name = @test_workspace

        -- Create test objects in schema level
        PRINT 'Creating test objects in schema level';
        SET @sql = 'CREATE TABLE ' + QUOTENAME(@destination_schema_name) + '.' + QUOTENAME(@test_table) + ' (id INT, name NVARCHAR(50))';
        EXEC sp_executesql @sql;

        SET @sql = 'CREATE VIEW ' + QUOTENAME(@destination_schema_name) + '.' + QUOTENAME(@test_view) + ' AS SELECT 1 as test_column';
        EXEC sp_executesql @sql;

        SET @sql = 'CREATE PROCEDURE ' + QUOTENAME(@destination_schema_name) + '.' + QUOTENAME(@test_procedure) + ' AS SELECT 1;';
        EXEC sp_executesql @sql;

        SET
            @sql = 'CREATE FUNCTION ' + QUOTENAME(@destination_schema_name) + '.' + QUOTENAME(@test_function)
            + '() RETURNS INT AS BEGIN RETURN 1 END;';
        EXEC sp_executesql @sql;

        -- Create test objects in workspace level
        PRINT 'Creating test objects in workspace level';
        SET @sql = 'CREATE TABLE ' + QUOTENAME(@test_workspace) + '.' + QUOTENAME(@test_table) + ' (id INT, name NVARCHAR(50))';
        EXEC sp_executesql @sql;

        SET @sql = 'CREATE VIEW ' + QUOTENAME(@test_workspace) + '.' + QUOTENAME(@test_view) + ' AS SELECT 1 as test_column';
        EXEC sp_executesql @sql;

        SET @sql = 'CREATE PROCEDURE ' + QUOTENAME(@test_workspace) + '.' + QUOTENAME(@test_procedure) + ' AS SELECT 1;';
        EXEC sp_executesql @sql;

        SET
            @sql = 'CREATE FUNCTION ' + QUOTENAME(@test_workspace) + '.' + QUOTENAME(@test_function)
            + '() RETURNS INT AS BEGIN RETURN 1 END;';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        PRINT ('Decommission test failed during setup phase.');
        PRINT (ERROR_MESSAGE());

        SET @now = GETDATE();
        UPDATE [UnitTests].[TestStatus]
        SET
            [result] = 'error',
            [test_end_time] = @now
        WHERE [test_name] = 'test_verification_ext_decom_functionality';
    END CATCH
END;

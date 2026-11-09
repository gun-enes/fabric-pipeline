BEGIN
    DECLARE @drop_cmd NVARCHAR(MAX);

    IF
        EXISTS (
            SELECT 1 FROM [UnitTests].[TestStatus]
            WHERE [result] IN ('failure', 'error')
        )
        BEGIN
            PRINT ('Deleting test objects');
            DELETE FROM [mgmt_xtinfra].[infra_config_settings]
            WHERE
                [workspace_name] = 'tsqltest'
                AND [name] = 'on-pause-pipeline-wait-opt-out';

            EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_run_to_version]
                @mode = 'downgrade',
                @start_version = 9999,
                @end_version = 0,
                @schema_name = 'tsqltest_test_schema',
                @predicate_function_name = '',
                @table_name = 'rls_test_table',
                @parameter_list = '';

            PRINT ('Deleting schedules');

            DELETE FROM [mgmt_xtinfra].[infra_schedule]
            WHERE [key] = 'decom_test_gatherstats';

            DELETE FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
            WHERE [infra_schedule_key] = 'decom_test_gatherstats';

            DELETE FROM [mgmt_xtinfra].[infra_expanded_schedule]
            WHERE [key] = 'decom_test_gatherstats';

            PRINT ('Deleting users');

            SELECT @drop_cmd = STRING_AGG(CAST(CONCAT(N'DROP USER ', QUOTENAME([name]), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)), CHAR(13))
            FROM [sys].[database_principals]
            WHERE [name] IN (
                'Data Platform-ADP-TDP-DMP-0002-TST-admin-mgmt',
                'Data Platform-ADP-TDP-DMP-0002-TST-contributor-mgmt',
                'Data Platform-ADP-TDP-DMP-0002-TST-operations-mgmt',
                'Data Platform-ADP-TDP-DMP-0002-TST-reader-mgmt',
                'az_adp_tdp_dmp_0002_tst_synapse_deploy', 'synw-tdp-0002-tst-mgmt', 'Data Platform-ADP-TDP-DMP-0001-TST-reader-mgmt'
            );

            PRINT (@drop_cmd);
            EXEC [sys].[sp_executesql] @drop_cmd;

            IF
                EXISTS (
                    SELECT 1
                    FROM [UnitTests].[KeyValueStore]
                    WHERE
                        [KeyName] = 'is_spf'
                        AND [Value] = '1'
                )
                BEGIN
                    EXEC [mgmt_xtinfra].[sp_testutil_spf_delete_static_schemas];
                END;

            SELECT
                @drop_cmd = STRING_AGG(
                    CAST(
                        CONCAT(N'DROP PROCEDURE ', QUOTENAME([s].[name]), '.', QUOTENAME([p].[name]), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(
                            MAX
                        )
                    ),
                    CHAR(13)
                )
            FROM [sys].[schemas] AS [s]
            INNER JOIN [sys].[procedures] AS [p]
                ON [s].[schema_id] = [p].[schema_id]
            WHERE [s].[name] IN ('tsqltest', 'tsqltest_test_schema');

            PRINT @drop_cmd;
            EXEC [sys].[sp_executesql] @drop_cmd;

            SELECT
                @drop_cmd = STRING_AGG(
                    CAST(
                        CONCAT(N'DROP VIEW ', QUOTENAME([s].[name]), '.', QUOTENAME([v].[name]), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)
                    ),
                    CHAR(13)
                )
            FROM [sys].[schemas] AS [s]
            INNER JOIN [sys].[views] AS [v]
                ON [s].[schema_id] = [v].[schema_id]
            WHERE
                [s].[name] IN ('tsqltest', 'tsqltest_test_schema');

            PRINT @drop_cmd;
            EXEC [sys].[sp_executesql] @drop_cmd;

            SELECT
                @drop_cmd = STRING_AGG(
                    CAST(
                        CONCAT(N'DROP TABLE ', QUOTENAME([s].[name]), '.', QUOTENAME([t].[name]), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)
                    ),
                    CHAR(13)
                )
            FROM [sys].[schemas] AS [s]
            INNER JOIN [sys].[tables] AS [t]
                ON [s].[schema_id] = [t].[schema_id]
            WHERE
                [s].[name] IN ('tsqltest', 'tsqltest_test_schema');

            PRINT @drop_cmd;
            EXEC [sys].[sp_executesql] @drop_cmd;

            SELECT
                @drop_cmd = STRING_AGG(
                    CAST(
                        CONCAT(N'DROP FUNCTION ', QUOTENAME([s].[name]), '.', QUOTENAME([o].[name]), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)
                    ),
                    CHAR(13)
                )
            FROM [sys].[schemas] AS [s]
            INNER JOIN [sys].[objects] AS [o]
                ON [s].[schema_id] = [o].[schema_id]
            WHERE
                [s].[name] IN ('tsqltest', 'tsqltest_test_schema')
                AND [o].[type] IN ('FN', 'IF', 'TF');

            PRINT @drop_cmd;
            EXEC [sys].[sp_executesql] @drop_cmd;

            -- Delete schema links (reader, writer, deployer)
            EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version]
                @mode = 'downgrade',
                @start_version = 9999,
                @end_version = 0,
                @source_schema_name = 'tsqltest',
                @source_schema_role_name = 'reader',
                @destination_schema_name = 'tsqltest_test_schema',
                @destination_schema_role_name = 'reader';

            EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version]
                @mode = 'downgrade',
                @start_version = 9999,
                @end_version = 0,
                @source_schema_name = 'tsqltest',
                @source_schema_role_name = 'writer',
                @destination_schema_name = 'tsqltest_test_schema',
                @destination_schema_role_name = 'writer';

            EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version]
                @mode = 'downgrade',
                @start_version = 9999,
                @end_version = 0,
                @source_schema_name = 'tsqltest',
                @source_schema_role_name = 'deployer',
                @destination_schema_name = 'tsqltest_test_schema',
                @destination_schema_role_name = 'deployer';

            -- Delete schema
            EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version]
                @mode = 'downgrade',
                @start_version = 9999,
                @end_version = 0,
                @schema_name = 'tsqltest_test_schema';

            PRINT 'Deleting workspace: tsqltest';
            EXEC [mgmt_xtinfra].[sp_infra_workspace_run_to_version]
                @mode = 'downgrade',
                @start_version = 9999,
                @end_version = 0,
                @workspace_name = 'tsqltest';
        END

    DELETE FROM [mgmt_xtinfra].[infra_workspace_identity_config]
    WHERE [workspace_name] IN (
        SELECT [Value]
        FROM [UnitTests].[KeyValueStore]
        WHERE [KeyName] = 'test_workspace'
    );

    DELETE FROM [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
    WHERE [workspace_name] IN (
        SELECT [Value]
        FROM [UnitTests].[KeyValueStore]
        WHERE [KeyName] = 'test_workspace'
    );

    PRINT ('Deleting test stored procedures');
    SELECT @drop_cmd = STRING_AGG(CAST(CONCAT(N'DROP PROCEDURE [UnitTests].', QUOTENAME([name]), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)), CHAR(13))
    FROM [sys].[procedures]
    WHERE SCHEMA_NAME([schema_id]) = 'UnitTests';

    PRINT @drop_cmd;
    EXEC [sys].[sp_executesql] @drop_cmd;

    PRINT ('Deleting test tables');
    SELECT @drop_cmd = STRING_AGG(CAST(CONCAT(N'DROP TABLE [UnitTests].', QUOTENAME([name]), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)), CHAR(13))
    FROM [sys].[tables]
    WHERE SCHEMA_NAME([schema_id]) = 'UnitTests';

    PRINT @drop_cmd;
    EXEC [sys].[sp_executesql] @drop_cmd;

    PRINT ('Deleting test schema');
    DROP SCHEMA [UnitTests];
END

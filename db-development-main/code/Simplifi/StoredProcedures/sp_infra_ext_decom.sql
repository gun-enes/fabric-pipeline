/*
Description:
Decommission extension componets

Author:
jyothish.b@allianz.com
*/

--owerwrite the sproc to add spf logic
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_ext_decom] @ops_type [NVARCHAR](8), @workspace_name [NVARCHAR](128) AS
BEGIN
    DECLARE
        @sql [NVARCHAR](MAX),
        @RoleName [NVARCHAR](128),
        @job_id [UNIQUEIDENTIFIER] = NEWID(),
        @date [DATETIME] = GETDATE(),
        @session_id [INT] = @@SPID,
        @session_user [NVARCHAR](128) = SESSION_USER,
        @job_name NVARCHAR(100) = N'Decommission Process for ' + @workspace_name;

    IF NOT (LEN(@workspace_name) BETWEEN 5 AND 10)
        BEGIN
            RAISERROR ('The ext name must be between 5 and 6 characters long.', 16, 1);
        END
    IF (@ops_type NOT IN ('decom', 'validate'))
        BEGIN
            RAISERROR ('Invalid ops type,either decom or validate', 16, 1);
        END

    -- Check operation type and extension name
    IF @ops_type = 'decom' AND @workspace_name IS NOT NULL
        BEGIN
            INSERT INTO mgmt_xtinfra.infra_job_master_v2
            (
                id, date, name, status, [session_id], [session_user]
            )
            VALUES
            (
                @job_id, @date, @job_name, 'started', @session_id, @session_user
            );

            -- Removing RLS policy from ADP environment
            WITH vw_rlspolicy AS (
                SELECT
                DISTINCT r.[schema_name], r.[table_name], m.[name]
                FROM [mgmt_xtinfra].[infra_object_master] AS m
                JOIN [mgmt_xtinfra].[infra_orders_details_rlspolicy] AS r
                    ON m.[name] = r.[schema_name] + '-policy-' + r.[table_name]
                JOIN [mgmt_xtinfra].[infra_orders_details_schemalinks] AS sl
                    ON r.[schema_name] = sl.[destination_schema_name]
                WHERE
                    m.[type] = 'rlspolicy'
                    AND m.[version] <> 0
                    AND sl.[source_schema_name] = @workspace_name
            )

            SELECT
                @sql = CAST(STRING_AGG(
                        'EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_run_to_version] ''downgrade'', 9999, 0, ''' + CAST(vw_rlspolicy.schema_name AS VARCHAR(MAX)) + ''', '''', ''' + CAST(vw_rlspolicy.table_name AS VARCHAR(MAX)) + ''', '''';', ' ') WITHIN GROUP (ORDER BY vw_rlspolicy.schema_name, vw_rlspolicy.table_name) AS NVARCHAR(MAX)
                )
            FROM vw_rlspolicy;
            EXEC sp_executesql @sql;

            -- ADP RLS Policy Removal in Simplfi
            -- If the ADP query is not working Simplifi absense of schemalink
            WITH vwrlsplcy AS (
                SELECT
                    LEFT([name], CHARINDEX('-policy', [name]) - 1) AS schemaname,
                    SUBSTRING([name], CHARINDEX('-policy-', [name]) + LEN('-policy-'), LEN([name])) AS tablename
                FROM mgmt_xtinfra.infra_object_master
                WHERE
                    type = 'rlspolicy'
                    AND version <> 0
                    AND name LIKE @workspace_name + '%-policy-%'
            )

            SELECT
                @sql = STRING_AGG(
                    'EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_run_to_version] ''downgrade'', 9999, 0, ''' + schemaname + ''', '''', ''' + tablename + ''', '''';', ' ')
                WITHIN GROUP (ORDER BY schemaname, tablename)
            FROM vwrlsplcy;
            EXEC sp_executesql @sql;
            -- Drop All Procedures in ADP environment
            SET
                @sql =
                (
                    SELECT STRING_AGG(CAST('DROP PROCEDURE ' + QUOTENAME(schema_name) + '.' + QUOTENAME(procedure_name) + '; ' AS NVARCHAR(MAX)),'')
                    FROM
                        (
                            SELECT s.[name] AS schema_name, p.[name] AS procedure_name
                            FROM [sys].[procedures] AS p
                            JOIN [sys].[schemas] AS s
                                ON p.[schema_id] = s.[schema_id]
                            WHERE
                                s.[name] IN
                                (
                                    SELECT DISTINCT [destination_schema_name]
                                    FROM [mgmt_xtinfra].[infra_orders_details_schemalinks]
                                    WHERE [source_schema_name] = @workspace_name
                                )
                            UNION ALL
                            SELECT s.[name] AS schema_name, p.[name] AS procedure_name
                            FROM [sys].[procedures] AS p
                            JOIN [sys].[schemas] AS s ON p.[schema_id] = s.[schema_id]
                            WHERE
                                s.[name] IN
                                (
                                    SELECT @workspace_name + '_' + [schema_name]
                                    FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                                )
                        ) AS adp_simplifi_combined
                );
            EXEC sp_executesql @sql;

            -- Drop All Functions in ADP and Simplifi environment
            SET
                @sql =
                (
                    SELECT STRING_AGG(CAST('DROP FUNCTION ' + QUOTENAME(schema_name) + '.' + QUOTENAME(function_name) + '; ' AS NVARCHAR(MAX)),'')
                    FROM
                        (
                            SELECT s.[name] AS schema_name, f.[name] AS function_name
                            FROM [sys].[objects] AS f
                            JOIN [sys].[schemas] AS s
                                ON f.[schema_id] = s.[schema_id]
                            WHERE
                                s.name IN
                                (
                                    SELECT DISTINCT [destination_schema_name]
                                    FROM [mgmt_xtinfra].[infra_orders_details_schemalinks]
                                    WHERE [source_schema_name] = @workspace_name
                                    UNION ALL
                                    SELECT @workspace_name
                                )
                                AND f.[type] IN ('FN', 'IF', 'TF')
                            UNION ALL
                            SELECT s.[name] AS schema_name, f.[name] AS function_name
                            FROM sys.[objects] AS f
                            JOIN sys.[schemas] AS s
                                ON f.[schema_id] = s.[schema_id]
                            WHERE
                                s.[name] IN
                                (
                                    SELECT @workspace_name + '_' + [schema_name]
                                    FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                                )
                                AND f.[type] IN ('FN', 'IF', 'TF')
                        ) AS adp_simplifi_combined
                );
            EXEC sp_executesql @sql;

            -- Drop All Views in ADP environment
            SET
                @sql =
                (
                    SELECT STRING_AGG(CAST('DROP VIEW ' + QUOTENAME(schema_name) + '.' + QUOTENAME(view_name) + '; ' AS NVARCHAR(MAX)),'')
                    FROM
                        (
                            SELECT s.[name] AS schema_name, v.[name] AS view_name
                            FROM [sys].[views] AS v
                            JOIN [sys].[schemas] AS s
                                ON v.[schema_id] = s.[schema_id]
                            WHERE
                                s.[name] IN
                                (
                                    SELECT DISTINCT [destination_schema_name]
                                    FROM [mgmt_xtinfra].[infra_orders_details_schemalinks]
                                    WHERE [source_schema_name] = @workspace_name
                                )
                            UNION ALL
                            SELECT s.[name] AS schema_name, v.[name] AS view_name
                            FROM [sys].[views] AS v
                            JOIN [sys].[schemas] AS s
                                ON v.[schema_id] = s.[schema_id]
                            WHERE
                                s.[name] IN
                                (
                                    SELECT @workspace_name + '_' + [schema_name]
                                    FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                                )
                        ) AS adp_simplifi_combined
                );
            EXEC sp_executesql @sql;

            -- Drop All Extension Tables Removal in ADP and Simplifi environment
            SET
                @sql =
                (
                    SELECT STRING_AGG(CAST('DROP TABLE ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + '; ' AS NVARCHAR(MAX)),'')
                    FROM
                        (
                            SELECT s.[name] AS schema_name, t.[name] AS table_name
                            FROM sys.[tables] AS t
                            JOIN sys.[schemas] AS s
                                ON t.[schema_id] = s.[schema_id]
                            WHERE
                                s.[name] IN
                                (
                                    SELECT @workspace_name + '_' + [schema_name]
                                    FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                                )
                            UNION ALL
                            SELECT s.[name] AS schema_name, t.[name] AS table_name
                            FROM sys.[tables] AS t
                            JOIN sys.[schemas] AS s
                                ON t.[schema_id] = s.[schema_id]
                            WHERE
                                s.name IN
                                (
                                    SELECT DISTINCT [destination_schema_name]
                                    FROM [mgmt_xtinfra].[infra_orders_details_schemalinks]
                                    WHERE [source_schema_name] = @workspace_name
                                    UNION ALL
                                    SELECT @workspace_name
                                )
                                AND t.[is_external] = 'False'
                        ) AS adp_simplifi_combined
                );
            EXEC sp_executesql @sql;

            -- Drop All External Tables in ADP and Simplifi environment
            SET
                @sql =
                (
                    SELECT STRING_AGG(CAST('DROP EXTERNAL TABLE ' + QUOTENAME(schema_name) + '.' + QUOTENAME(table_name) + '; ' AS NVARCHAR(MAX)),'')
                    FROM
                        (
                            SELECT s.[name] AS schema_name, t.[name] AS table_name
                            FROM sys.[external_tables] AS t
                            JOIN sys.[schemas] AS s
                                ON t.[schema_id] = s.[schema_id]
                            WHERE
                                s.name IN
                                (
                                    SELECT DISTINCT [destination_schema_name]
                                    FROM [mgmt_xtinfra].[infra_orders_details_schemalinks]
                                    WHERE [source_schema_name] = @workspace_name
                                    UNION ALL
                                    SELECT @workspace_name
                                )
                            UNION ALL
                            SELECT
                                s.[name] AS schema_name, t.[name] AS table_name
                            FROM [sys].[external_tables] AS t
                            JOIN [sys].[schemas] AS s
                                ON t.[schema_id] = s.[schema_id]
                            WHERE
                                s.[name] IN
                                (
                                    SELECT @workspace_name + '_' + [schema_name]
                                    FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                                )
                        ) AS adp_simplifi_combined
                );
            EXEC sp_executesql @sql;

            -- Downgrading Schemalink for ADP
            WITH vw_schemalink AS (
                SELECT DISTINCT
                    l.[source_schema_name],
                    s.[name] AS destination_schema_name
                FROM [sys].[schemas] AS s
                JOIN [mgmt_xtinfra].[infra_orders_details_schemalinks] AS l
                    ON s.[name] = l.[destination_schema_name]
                WHERE l.[source_schema_name] = @workspace_name
            )

            SELECT
                @sql = STRING_AGG(CAST(
                    'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''downgrade'', 9999, 0, ''' + vw.source_schema_name + ''', ''writer'', ''' + vw.destination_schema_name + ''', ''writer''; ' +
                    'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''downgrade'', 9999, 0, ''' + vw.source_schema_name + ''', ''reader'', ''' + vw.destination_schema_name + ''', ''reader''; ' +
                    'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''downgrade'', 9999, 0, ''' + vw.source_schema_name + ''', ''deployer'', ''' + vw.destination_schema_name + ''', ''deployer''; ' AS NVARCHAR(MAX)),'') WITHIN GROUP (ORDER BY vw.destination_schema_name)
            FROM vw_schemalink AS vw;
            EXEC sp_executesql @sql;

            -- Downgrading Schema for ADP
            WITH vw_schemadowng AS (
                SELECT DISTINCT s.[name] AS destination_schema_name
                FROM [sys].[schemas] AS s
                JOIN [mgmt_xtinfra].[infra_orders_details_schemalinks] AS l
                    ON s.[name] = l.[destination_schema_name]
                WHERE l.[source_schema_name] = @workspace_name
            )

            SELECT
                @sql = STRING_AGG(CAST(
                    'EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] ''downgrade'', 9999, 0, ''' + vw.destination_schema_name + '''; ' AS NVARCHAR(MAX)),'') WITHIN GROUP (ORDER BY vw.destination_schema_name)
            FROM vw_schemadowng AS vw;
            EXEC sp_executesql @sql;

            -- Drop all respective extension schemas for simplifi
            -- Downgrading Schemalink for SPF
            WITH workspace_schema_spf AS (
            SELECT @workspace_name as wks_name, schema_name FROM [mgmt_xtinfra].[infra_static_ext_schemas] )
            SELECT @sql = STRING_AGG(
                CAST(
                    'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''downgrade'', 9999, 0, ''' + @workspace_name + ''', ''writer'', ''' + s.name + ''', ''writer''; ' +
                    'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''downgrade'', 9999, 0, ''' + @workspace_name + ''', ''reader'', ''' + s.name + ''', ''reader''; ' +
                    'EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] ''downgrade'', 9999, 0, ''' + @workspace_name + ''', ''deployer'', ''' + s.name + ''', ''deployer''; ' AS NVARCHAR(MAX)),''
                    )
            FROM sys.[schemas] AS s
            JOIN workspace_schema_spf
            ON s.[name] = workspace_schema_spf.[wks_name] +'_'+ workspace_schema_spf.[schema_name];
            EXEC sp_executesql @sql;

            -- Clean up Reporting user just simplifi project
            -- Reporting ext user for ADP = core reader hence ignoring the same
            SET
                @sql =
                (
                    SELECT STRING_AGG('DROP USER ' + QUOTENAME([reporting_group_name]) + '; ', '')
                    FROM [mgmt_xtinfra].[infra_workspace_reporting_groups_config]
                    WHERE [workspace_name] = @workspace_name
                );
            EXEC sp_executesql @sql;

            SET
                @sql =
                (
                    SELECT
                        STRING_AGG(CAST('EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] ''downgrade'', 9999, 0, '''+ (s.name) + '''; ' AS NVARCHAR(MAX)),'')
                    FROM sys.[schemas] AS s
                    WHERE
                        s.[name] IN
                        (
                            SELECT @workspace_name + '_' + schema_name FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                        )
                );
            EXEC sp_executesql @sql;

            -- Dropping extension users for both adp and simplifi
            SET
                @sql = (
                    SELECT
                        STRING_AGG(
                            CASE WHEN dp.[name] IS NOT NULL AND dp.[name] = iwic.[admin_group_name] THEN 'DROP USER [' + iwic.[admin_group_name] + ']; ' ELSE '' END +
                            CASE WHEN dp.[name] IS NOT NULL AND dp.[name] = iwic.[contributor_group_name] THEN 'DROP USER [' + iwic.[contributor_group_name] + ']; ' ELSE '' END +
                            CASE WHEN dp.[name] IS NOT NULL AND dp.[name] = iwic.[operations_group_name] THEN 'DROP USER [' + iwic.[operations_group_name] + ']; ' ELSE '' END +
                            CASE WHEN dp.[name] IS NOT NULL AND dp.[name] = iwic.[reader_group_name] THEN 'DROP USER [' + iwic.[reader_group_name] + ']; ' ELSE '' END +
                            CASE WHEN dp.[name] IS NOT NULL AND dp.[name] = iwic.[service_principal_name] THEN 'DROP USER [' + iwic.[service_principal_name] + ']; ' ELSE '' END +
                            CASE WHEN dp.[name] IS NOT NULL AND dp.[name] = iwic.[synapse_workspace_msi_name] THEN 'DROP USER [' + iwic.[synapse_workspace_msi_name] + ']; ' ELSE '' END +
                            CASE WHEN dp.[name] IS NOT NULL AND dp.[name] = iwic.[actions_group_name] THEN 'DROP USER [' + iwic.[actions_group_name] + ']; ' ELSE '' END, '')
                    FROM [mgmt_xtinfra].[infra_workspace_identity_config] AS iwic
                    LEFT JOIN sys.database_principals AS dp
                        ON dp.[name] IN (
                            iwic.[admin_group_name],
                            iwic.[contributor_group_name],
                            iwic.[operations_group_name],
                            iwic.[reader_group_name],
                            iwic.[service_principal_name],
                            iwic.[synapse_workspace_msi_name],
                            iwic.[actions_group_name]
                        )
                    WHERE
                        iwic.[workspace_name] = @workspace_name
                        AND
                        (dp.[type] IN ('X', 'E'))
                );
            EXEC sp_executesql @sql;

            -- Remove all the extension user defined roles for simplifi
            CREATE TABLE #RolesToDrop ([RoleName] NVARCHAR(128));
            INSERT INTO #RolesToDrop ([RoleName])
            SELECT r.[name]
            FROM sys.[database_principals] AS r
            WHERE
                r.[type] = 'R' AND r.[name] IN
                (
                    SELECT @workspace_name + '_' + [schema_name] + '-schema-deployer'
                    FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                    UNION ALL
                    SELECT @workspace_name + '_' + [schema_name] + '-schema-reader'
                    FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                    UNION ALL
                    SELECT @workspace_name + '_' + [schema_name] + '-schema-writer'
                    FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                );
            WHILE EXISTS (SELECT 1 FROM #RolesToDrop)
                BEGIN
                    SELECT TOP 1 @RoleName = [RoleName] FROM #RolesToDrop;
                    SET @sql = 'DROP ROLE ' + QUOTENAME(@RoleName) + ';';
                    EXEC sp_executesql @sql;
                    DELETE FROM #RolesToDrop WHERE [RoleName] = @RoleName;
                END
            DROP TABLE #RolesToDrop;
            -- Delete records from infra_schedule table
            DELETE FROM [mgmt_xtinfra].[infra_schedule]
            WHERE
                [key] IN
                (
                    SELECT [infra_schedule_key]
                    FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
                    WHERE
                        [schema_name] IN
                        (
                            SELECT DISTINCT [destination_schema_name]
                            FROM
                                [mgmt_xtinfra].[infra_orders_details_schemalinks]
                            WHERE [source_schema_name] = @workspace_name
                        )
                    UNION
                    SELECT [infra_schedule_key]
                    FROM
                        [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
                    WHERE
                        [schema_name] IN
                        (
                            SELECT @workspace_name + '_' + schema_name
                            FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                        )
                );

            -- Deleting extension schema stats gather self service
            DELETE FROM [mgmt_xtinfra].[infra_expanded_schedule]
            WHERE
                [key] IN
                (
                    SELECT [infra_schedule_key]
                    FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
                    WHERE
                        [schema_name] IN
                        (
                            SELECT DISTINCT [destination_schema_name]
                            FROM
                                [mgmt_xtinfra].[infra_orders_details_schemalinks]
                            WHERE [source_schema_name] = @workspace_name
                        )
                    UNION
                    SELECT [infra_schedule_key]
                    FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
                    WHERE
                        [schema_name] IN
                        (
                            SELECT @workspace_name + '_' + [schema_name]
                            FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                        )
                );

            -- Deleting extension schema stats gather self service
            DELETE FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
            WHERE
                [schema_name] IN
                (
                    SELECT DISTINCT [destination_schema_name]
                    FROM [mgmt_xtinfra].[infra_orders_details_schemalinks]
                    WHERE [source_schema_name] = @workspace_name
                    UNION
                    SELECT @workspace_name + '_' + schema_name
                    FROM [mgmt_xtinfra].[infra_static_ext_schemas]
                );

            -- Deleting opt-out self-service component for respective ext
            DELETE FROM [mgmt_xtinfra].[infra_config_settings]
            WHERE [workspace_name] = @workspace_name;

            -- Remove core members from the workspace schema roles
            WITH vwrolemem AS (
                SELECT
                    r.[name] AS rolename,
                    p.[name] AS membername
                FROM
                    [sys].[database_role_members] AS m
                JOIN [sys].[database_principals] AS r
                    ON m.[role_principal_id] = r.[principal_id]
                JOIN [sys].[database_principals] AS p
                    ON m.[member_principal_id] = p.[principal_id]
                WHERE r.[name] IN
                    (@workspace_name + '-schema-reader', @workspace_name + '-schema-writer', @workspace_name + '-schema-deployer')
            )

            SELECT @sql = CAST(STRING_AGG('EXEC sp_droprolemember ''' + rolename + ''', ''' + membername + ''';', ' ') AS NVARCHAR(MAX))
            FROM vwrolemem;
            EXEC sp_executesql @sql;

            -- Removing Customer created objects from WorkspaceSchema
            SET
                @sql = (
                    SELECT
                        STRING_AGG(
                            'DROP ' +
                            CASE o.[type]
                                WHEN 'P' THEN 'PROCEDURE '
                                WHEN 'FN' THEN 'FUNCTION '
                                WHEN 'IF' THEN 'FUNCTION '
                                WHEN 'TF' THEN 'FUNCTION '
                                WHEN 'V' THEN 'VIEW '
                                WHEN 'U' THEN 'TABLE '
                                WHEN 'ET' THEN 'EXTERNAL TABLE '
                            END +
                            QUOTENAME(@workspace_name) + '.' + QUOTENAME(o.name) + ';', ' '
                        )
                    FROM [sys].[objects] AS o
                    WHERE
                        o.[schema_id] = SCHEMA_ID(@workspace_name)
                        AND o.[name] NOT LIKE 'sp_workspace_%'
                        AND o.[name] NOT IN ('v_expanded_gatherstats_schedule','v_expanded_schedule','v_infra_config_settings','v_schedule')
                        AND o.[type] IN ('P', 'FN', 'IF', 'TF', 'V', 'U','ET')
                );
            EXEC sp_executesql @sql;

            -- Finally removing the workspace schema
            EXEC [mgmt_xtinfra].[sp_infra_workspace_run_to_version] 'downgrade', 9999, 0,@workspace_name

            SET @date = GETDATE()
            INSERT INTO [mgmt_xtinfra].[infra_job_master_v2]
            ([id], [date], [name], [status], [session_id], [session_user])
            VALUES
            (@job_id, @date, @job_name, 'completed', @session_id, @session_user);
        END -- Decommission block end here
    ELSE
        BEGIN   -- Decommission validation block stats here
            PRINT 'Parameters for extension decommission are not provided';
        END
END;
GO

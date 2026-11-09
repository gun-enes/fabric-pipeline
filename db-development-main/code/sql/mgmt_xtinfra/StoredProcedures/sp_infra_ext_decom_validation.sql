/*
Description:
Decommission extension componets

Author:
jyothish.b@allianz.com
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_ext_decom_validation]
    @workspace_name [NVARCHAR](128)
AS
BEGIN
    DECLARE
        @existingObjectCount [INT],
        @job_id [UNIQUEIDENTIFIER] = NEWID(),
        @date [DATETIME] = GETDATE(),
        @session_id [INT] = @@SPID,
        @session_user [NVARCHAR](128) = SESSION_USER,
        @job_name [NVARCHAR](100) = N'Decommission Validation Process for ' + @workspace_name,
        @proc_name nvarchar(128) = 'sp_infra_ext_decom_validation';

  BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @job_id, @proc_name, 'started';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @job_id, 'workspace_name', @workspace_name;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @job_id, 'job_name', @job_name;
    -- Check if the table exists and truncate it
    IF OBJECT_ID('mgmt_xtinfra.infra_ext_decom_log', 'U') IS NOT NULL
        BEGIN
            TRUNCATE TABLE [mgmt_xtinfra].[infra_ext_decom_log];
        END

    UPDATE STATISTICS [mgmt_xtinfra].[infra_ext_decom_log];

    -- Insert counts into infra_ext_decom_log
    WITH vwobjectgrp AS (
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'TABLE' AS objecttype,
            s.[name] AS schemaname,
            t.[name] AS objectname,
            'EligibleForDecom' AS info
        FROM [sys].[tables] AS t
        INNER JOIN [sys].[schemas] AS s ON t.[schema_id] = s.[schema_id]
        WHERE s.[name] LIKE '%' + @workspace_name + '%'
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'VIEWS' AS objecttype,
            s.[name] AS schemaname,
            v.[name] AS objectname,
            'EligibleForDecom' AS info
        FROM [sys].[views] AS v
        INNER JOIN [sys].[schemas] AS s ON v.[schema_id] = s.[schema_id]
        WHERE s.[name] LIKE '%' + @workspace_name + '%'
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'PROCEDURE' AS objecttype,
            s.[name] AS schemaname,
            p.[name] AS objectname,
            'EligibleForDecom' AS info
        FROM [sys].[procedures] AS p
        INNER JOIN [sys].[schemas] AS s ON p.[schema_id] = s.[schema_id]
        WHERE s.[name] LIKE '%' + @workspace_name + '%'
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'FUNCTION' AS objecttype,
            s.[name] AS schemaname,
            f.[name] AS objectname,
            'EligibleForDecom' AS info
        FROM [sys].[objects] AS f
        INNER JOIN [sys].[schemas] AS s ON f.[schema_id] = s.[schema_id]
        WHERE
            f.[type] IN ('FN', 'IF', 'TF')
            AND s.[name] LIKE '%' + @workspace_name + '%'
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'SCHEMA' AS objecttype,
            s.[name] AS schemaname,
            NULL AS objectname,
            'EligibleForDecom' AS info
        FROM [sys].[schemas] AS s
        WHERE s.[name] LIKE '%' + @workspace_name + '%'
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'EXTERNAL_TABLE' AS objecttype,
            s.[name] AS schemaname,
            t.[name] AS objectname,
            'EligibleForDecom' AS info
        FROM [sys].[external_tables] AS t
        INNER JOIN [sys].[schemas] AS s ON t.[schema_id] = s.[schema_id]
        WHERE s.[name] LIKE '%' + @workspace_name + '%'
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'USERS' AS objecttype,
            NULL AS schemaname,
            user_principals.[name] AS objectname,
            'EligibleForDecom' AS info
        FROM (
            SELECT dp.[name]
            FROM [mgmt_xtinfra].[infra_workspace_identity_config] AS iwic
            INNER JOIN [sys].[database_principals] AS dp
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
                AND dp.[type] IN ('X', 'E')
            UNION ALL
            SELECT dp.[name]
            FROM [sys].[database_principals] AS dp
            WHERE
                dp.[name] LIKE 'Data Platform-spf-%rep-reader%' + @workspace_name
        ) AS user_principals
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'ROLES' AS objecttype,
            NULL AS schemaname,
            r.[name] AS objectname,
            'EligibleForDecom' AS info
        FROM [sys].[database_principals] AS r
        WHERE r.[type] = 'R' AND r.[name] LIKE '%' + @workspace_name + '%'
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'INFRA_SCHEDULE' AS objecttype,
            NULL AS schemaname,
            NULL AS objectname,
            'EligibleForDecom' AS info
        FROM [mgmt_xtinfra].[infra_schedule]
        WHERE
            [key] IN (
                SELECT [infra_schedule_key]
                FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
                WHERE [schema_name] LIKE '%' + @workspace_name + '%'
            )
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'INFRA_EXPANDED_SCHEDULE' AS objecttype,
            NULL AS schemaname,
            NULL AS objectname,
            'EligibleForDecom' AS info
        FROM [mgmt_xtinfra].[infra_expanded_schedule]
        WHERE
            [key] IN (
                SELECT [infra_schedule_key]
                FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
                WHERE [schema_name] LIKE '%' + @workspace_name + '%'
            )
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'INFRA_GATHERSTATS_SCHEDULE_DETAIL' AS objecttype,
            NULL AS schemaname,
            NULL AS objectname,
            'EligibleForDecom' AS info
        FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
        WHERE [schema_name] LIKE '%' + @workspace_name + '%'
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            ('INFRA_OBJECT_MASTER-' + type + '.V0' + CAST(version AS NVARCHAR(10))) AS objecttype,
            NULL AS schemaname,
            [name] AS objectname,
            'EligibleForDecom' AS info
        FROM [mgmt_xtinfra].[infra_object_master]
        WHERE [name] LIKE '%' + @workspace_name + '%' AND version > 0
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rownum,
            'INFRA_CONFIG_SETTINGS' AS objecttype,
            NULL AS schemaname,
            NULL AS objectname,
            'EligibleForDecom' AS info
        FROM [mgmt_xtinfra].[infra_config_settings]
        WHERE [workspace_name] LIKE '%' + @workspace_name + '%'
    )

    INSERT INTO [mgmt_xtinfra].[infra_ext_decom_log]
    (
        [LogID],
        [ObjectType],
        [SchemaName],
        [ObjectName],
        [Info],
        [Timestamp]
    )
    SELECT
        (
            (SELECT ISNULL(MAX(LogID), 0) FROM mgmt_xtinfra.infra_ext_decom_log)
            + rownum
        ),
        objecttype,
        schemaname,
        objectname,
        info,
        GETDATE()
    FROM vwobjectgrp;

    -- complete log
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @job_id, @proc_name, 'success';
  END TRY
  BEGIN CATCH
    DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @error_severity INT = ERROR_SEVERITY();
    DECLARE @error_state INT = ERROR_STATE();
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @job_id, 'error_message', @error_message
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @job_id, 'error_severity', @error_severity
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @job_id, 'error_state', @error_state
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution @job_id, @proc_name, 'failure';
    --- then throw again to forward error
    THROW;
  END CATCH
END;
GO

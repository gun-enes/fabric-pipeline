CREATE PROC [mgmt_xtinfra].[sp_infra_backup_runner]
    @dir_name varchar(4000),
    @restore_type varchar(4000),
    @schema_name varchar(4000),
    @table_name varchar(4000)
/*
	Project  : ADP
	Author   : jyothish.b@allianz.com
	Description : Database DB Backup and logical restore operations DB
*/
AS
BEGIN
    DECLARE @cmd varchar(4000)
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @proc_name nvarchar(128) = 'sp_infra_backup_runner';
   BEGIN TRY
     EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
     EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'dir_name', @dir_name;
	 EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'restore_type', @restore_type;
     EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'schema_name', @schema_name;
	 EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'table_name', @table_name;
    DECLARE
        @session_id_counter int = (
            SELECT
                ISNULL(
                    MAX([session_id]), 0
                )
            FROM
                [mgmt_xtinfra].[infra_dr_backup_master]
        ) + 1
    DECLARE
        @exec_id_counter int = (
            SELECT
                ISNULL(MAX([execid]), 0
                ) AS [maxexecid]
            FROM
                [mgmt_xtinfra].[infra_dr_backup_master]
        ) + 1
    DECLARE @db_name varchar(1000)
    DECLARE @current_user varchar(1000)
    DECLARE
        @now datetime = (
            SELECT SYSDATETIME()
        )
    IF (@dir_name IS NULL)
        BEGIN
            SET
                @dir_name = (
                    SELECT CONVERT(varchar(8), SYSDATETIME(), 112) + REPLACE(CONVERT(varchar(5), SYSDATETIME(), 108), ':', '') AS formatteddate
                );
        END
    IF COUNT(@dir_name) > 12
        BEGIN;
            THROW 555550,
            'Invalid value for @dir_name param.yyyymmdd format,Ex-20240426', 1;
        END;

    DECLARE @output varchar(1000) = 'TEST'
    DECLARE @job_desc varchar(1000) = 'Infra DR backup master operation for DR'
    SET
        @db_name = DB_NAME();
    SET
        @current_user = CURRENT_USER;

    IF @restore_type NOT IN ('FULL', 'SCHEMA', 'TABLE')
        BEGIN;
            THROW 555550,
            'Invalid value for @restore_type parameter. Expected values: FULL, SCHEMA, or TABLE', 1;
        END

    IF @restore_type IN ('SCHEMA', 'TABLE')
        BEGIN
            IF @schema_name IS NULL
                BEGIN;
                    THROW 555550,
                    'Parameter @schema_name is required when @restore_type is SCHEMA or TABLE', 1;
                END

            IF
                NOT EXISTS (
                    SELECT 1 FROM [sys].[schemas]
                    WHERE
                        [name] = @schema_name
                )
                BEGIN;
                    THROW 555550,
                    'Invalid input for @schema_name parameter. Schema not found in the database', 1;
                END
        END

    IF @restore_type = 'TABLE'
        BEGIN
            IF @table_name IS NULL
                BEGIN;
                    THROW 555550, 'Parameter @table_name is required when @restore_type is TABLE', 1;
                END

            IF
                NOT EXISTS (
                    SELECT 1
                    FROM [sys].[tables]
                    WHERE
                        [name] = @table_name
                        AND SCHEMA_NAME([schema_id]) = @schema_name
                )
                BEGIN;
                    THROW 555550, 'Invalid input for @table_name parameter. Table not found in the specified schema', 1;
                END
        END

    TRUNCATE TABLE [mgmt_xtinfra].[infra_dr_backup_master];

    INSERT INTO [mgmt_xtinfra].[infra_dr_backup_master] (
        [execid],
        [session_id],
        [exec_user],
        [db_name],
        [exec_time],
        [table_schema],
        [table_name],
        [filename],
        [sectionid],
        [dir_name],
        [tab_rename],
        [status],
        [hash_validation]
    )
    SELECT
        @exec_id_counter + 1 AS execid,
        @session_id_counter + 1 AS session_id,
        @current_user AS exec_user,
        @db_name AS db_name,
        @now AS exec_time,
        SCHEMA_NAME(t.schema_id) AS table_schema,
        t.name AS table_name,
        +@dir_name + '/' + SCHEMA_NAME(t.schema_id) + '.' + t.name + '.bck' AS filename,
        NTILE(4) OVER (ORDER BY NEWID()) AS sectionid,
        @dir_name AS dir_name,
        CASE
            WHEN
                SCHEMA_NAME([t].[schema_id]) = 'mgmt_xtinfra'
                AND [t].[name] = 'infra_dr_backup_master'
                THEN [t].[name]
            ELSE [t].[name] + '_' + @dir_name
        END AS [tab_rename],
        'NEW' AS [status],
        CASE
            WHEN
                SCHEMA_NAME([t].[schema_id]) = 'mgmt_xtinfra'
                AND [t].[name] IN ('infra_dr_backup_master', 'infra_job_master_v2_details', 'infra_job_master_v2')
                THEN 0
            ELSE 1
        END AS [hash_validation]
    FROM [sys].[tables] AS [t]
    WHERE
        [t].[is_external] = 0
        AND (
            @restore_type = 'FULL'
            OR (@restore_type = 'SCHEMA' AND SCHEMA_NAME([t].[schema_id]) = @schema_name)
            OR (@restore_type = 'TABLE' AND SCHEMA_NAME([t].[schema_id]) = @schema_name AND [t].[name] = @table_name)
            OR (
                SCHEMA_NAME([t].[schema_id]) = 'mgmt_xtinfra'
                AND [t].[name] = 'infra_dr_backup_master'
            )
        )
    GROUP BY
        [t].[schema_id],
        [t].[name];
    -- complete log
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';
   END TRY
   BEGIN CATCH
		DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
		DECLARE @error_severity INT = ERROR_SEVERITY();
		DECLARE @error_state INT = ERROR_STATE();
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_message', @error_message
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_severity', @error_severity
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_state', @error_state
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'failure';
        --- then throw again to forward error
        THROW;
   END CATCH
END
GO

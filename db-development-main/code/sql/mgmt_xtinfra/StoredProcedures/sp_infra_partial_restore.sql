 /* Scope    : Partial DB Restore from SourceDB to TargetDB
 * Project   : Simplfi
 * Activity  : Dedicated SQL pool deployment
 * Author    : jyothish.b@allianz.com
 */

CREATE PROC [mgmt_xtinfra].[sp_infra_partial_restore] @tab_ext [varchar](4000),@restore_type [varchar](4000),@schema_name [varchar](4000),@table_name [varchar](4000) AS
BEGIN
    DECLARE @cmd varchar(4000)
    DECLARE @proc_name varchar(100) = 'sp_infra_partial_restore';
    DECLARE @log_detail_group uniqueidentifier = NEWID();

    BEGIN TRY
         --- add log entry for our job
	    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'schema_name', @schema_name
	    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'restore_type', @restore_type
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'table_name', @table_name

        DECLARE @session_id_counter int = (
        SELECT
            ISNULL(MAX(session_id), 0)
        FROM
            mgmt_xtinfra.infra_partial_restore_master) + 1
        DECLARE @exec_id_counter int = (
        SELECT
            ISNULL(MAX(execid), 0) AS maxexecid
        FROM
            mgmt_xtinfra.infra_partial_restore_master) + 1
        DECLARE @db_name varchar(1000)
        DECLARE @current_user varchar(1000)
        DECLARE @now DateTime =(
            select
                SYSDATETIME())
        IF (@tab_ext IS NULL)
            BEGIN
                SET
                @tab_ext = (SELECT CONVERT(varchar(8), SYSDATETIME(), 112) + REPLACE(CONVERT(varchar(5), SYSDATETIME(), 108), ':', '')  AS FormattedDate);
            END
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'tab_ext', @tab_ext
        IF count(@tab_ext) > 12
            BEGIN
                ;THROW 555550,
                'Invalid input for @tab_ext parameter.Expected values in yyyymmdd format,Example 20240426 (26th April 2024)',
                1;
            END
        IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = @schema_name)
            BEGIN
                ;THROW 555551,
                'Invalid input for @schema_name parameter.Schema not found in the DB',
                1;
            END
        IF (@restore_type = 'TABLE')
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = @table_name)
                BEGIN
                    ;THROW 555552,
                    'Invalid input for @table_name parameter.Table not found in the DB',
                    1;
                END
            END
        DECLARE @output varchar(1000) = 'TEST'
        DECLARE @job_desc varchar(1000) = 'Infra Restore Operation'
        SET @db_name = db_name();
        SET @current_user = current_user;

        IF (@restore_type = 'SCHEMA')
            BEGIN
                truncate table [mgmt_xtinfra].[infra_partial_restore_master];
                INSERT
                    INTO
                    mgmt_xtinfra.infra_partial_restore_master (execid ,
                    session_id,
                    exec_user ,
                    db_name ,
                    exec_time,
                    table_schema,
                    table_name,
                    filename,
                    sectionid,
                    tab_ext,tab_rename)
                SELECT @exec_id_counter+1,@session_id_counter+1,
                    @current_user,@db_name,
                    @now, SCHEMA_NAME(t.schema_id)
                    , t.name
                    , + @tab_ext + '/' + SCHEMA_NAME(t.schema_id) + '.' + t.name + '.bck'
                    ,ntile(4) over (order by newid()) ,@tab_ext,t.name + '_' + @tab_ext
                FROM sys.tables t
                LEFT JOIN sys.external_tables e
                    on t.object_id = e.object_id
                    where e.type is NULL
                    and SCHEMA_NAME(t.schema_id)=@schema_name --and t.name=@table_name
            END
        IF (@restore_type = 'TABLE')
            BEGIN
                truncate table [mgmt_xtinfra].[infra_partial_restore_master];
                INSERT
                    INTO
                    mgmt_xtinfra.infra_partial_restore_master (execid ,
                    session_id,
                    exec_user ,
                    db_name ,
                    exec_time,
                    table_schema,
                    table_name,
                    filename,
                    sectionid,
                    tab_ext,tab_rename)
                SELECT @exec_id_counter+1,@session_id_counter+1,
                    @current_user,@db_name,
                    @now, SCHEMA_NAME(t.schema_id)
                    , t.name
                    , + @tab_ext + '/' + SCHEMA_NAME(t.schema_id) + '.' + t.name + '.bck'
                    ,ntile(4) over (order by newid()) ,@tab_ext,t.name + '_' + @tab_ext
                FROM sys.tables t
                LEFT JOIN sys.external_tables e
                    on t.object_id = e.object_id
                    where e.type is NULL
                    and SCHEMA_NAME(t.schema_id)=@schema_name and t.name=@table_name
            END
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'success';
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

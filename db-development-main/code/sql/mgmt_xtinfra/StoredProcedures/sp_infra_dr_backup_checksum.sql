/*
Description: Simplifi DR Backup Table hash calulator

Author: jyothish.b@allianz.com
*/


CREATE PROCEDURE mgmt_xtinfra.sp_infra_dr_backup_checksum
    @OPS_TYPE [VARCHAR](16)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @proc_name nvarchar(128) = 'sp_infra_dr_backup_checksum';
   BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'OPS_TYPE', @OPS_TYPE;
    IF @OPS_TYPE NOT IN ('SOURCE', 'TARGET', 'TARGET_PITR')
        BEGIN
            DECLARE
                @ErrorMsg NVARCHAR(200) = 'Invalid @OPS_TYPE parameter. Must be ''SOURCE'', ''TARGET'', or ''TARGET_PITR''. Provided value: ' + ISNULL(@OPS_TYPE, 'NULL');
            THROW 50001, @ErrorMsg, 1;
        END

    DECLARE @dest_column_name NVARCHAR(17);
    DECLARE @table_column_name NVARCHAR(50) = 'table_name';
    ---------------------------------------------------------------------
    -- 1. Get distinct tables into a temp table with row numbers for WHILE
    ---------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#tbls') IS NOT NULL DROP TABLE #tbls;
    CREATE TABLE #tbls (
        rn INT,
        [schema_name] SYSNAME,
        [table_name] SYSNAME
    );

    INSERT INTO #tbls (rn, schema_name, table_name)
    SELECT
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn,
        [table_schema],
        CASE
            WHEN @OPS_TYPE = 'TARGET_PITR' THEN [tab_rename]
            ELSE [table_name]
        END AS [table_name]
    FROM (
        SELECT DISTINCT
            [table_schema],
            [table_name],
            [tab_rename]
        FROM [mgmt_xtinfra].[infra_dr_backup_master]
    ) AS a;

    IF (@OPS_TYPE = 'SOURCE')
        BEGIN
            SET @dest_column_name = 'source_table_hash'
        END
    ELSE
        BEGIN
            SET @dest_column_name = 'target_table_hash'
            IF (@OPS_TYPE = 'TARGET_PITR')
                BEGIN
                    SET @table_column_name = 'tab_rename'
                END
        END

    DECLARE @max INT, @i INT = 1;
    SELECT @max = COUNT(*) FROM #tbls;
    DECLARE
        @SchemaName SYSNAME,
        @TableName SYSNAME,
        @sql NVARCHAR(MAX),
        @hash VARBINARY(8000);
    WHILE @i <= @max
        BEGIN
            -- Fetch schema & table
            SELECT
                @SchemaName = schema_name,
                @TableName = table_name
            FROM #tbls
            WHERE rn = @i;

            SET @sql = '
                SELECT @hOUT =
                    HASHBYTES(
                    ''SHA2_256'',
                    CAST(SUM(CAST(BINARY_CHECKSUM(*) AS BIGINT)) AS VARCHAR(MAX))
                    )
                FROM ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ';
                    ';

            EXEC sp_executesql
                @sql,
                N'@hOUT VARBINARY(8000) OUTPUT',
                @hOUT = @hash OUTPUT;

            SET @sql = '
                UPDATE [mgmt_xtinfra].[infra_dr_backup_master]
                    SET ' + QUOTENAME(@dest_column_name) + ' = @hash
                WHERE
                    [table_schema] = @SchemaName
                    AND [' + @table_column_name + '] = @TableName;';

            EXEC sp_executesql
                @sql,
                N'@hash VARBINARY(64), @SchemaName SYSNAME, @TableName SYSNAME',
                @hash, @SchemaName, @TableName;

            SET @i = @i + 1;
        END;

    DROP TABLE #tbls;
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

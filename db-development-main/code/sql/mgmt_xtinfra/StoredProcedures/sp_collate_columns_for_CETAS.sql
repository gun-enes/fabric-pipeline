/*
    Description:
        Builds the dynamic SELECT statement used for CETAS during backup.

        - Empty strings ('') in character columns are converted to 0x00 because
          the default binary conversion turns them into NULL, which causes
          problems during restore.
        - Non-empty character values are converted to VARBINARY(MAX) to preserve
          UTF-8, since external tables do not keep UTF-8 encoding.
        - uniqueidentifier values are converted to CHAR(255) for a stable,
          reversible representation.

    Author:
        extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_collate_columns_for_CETAS] (@schema_name NVARCHAR(43), @table_name NVARCHAR(200), @sql NVARCHAR(MAX) OUTPUT)
AS
BEGIN
    DECLARE @col VARCHAR(200)
    DECLARE @isChar BIT;
    DECLARE @isUniqueID BIT;
    DECLARE @table_row_count INT;
    DECLARE @row_id INT = 1;
    DECLARE @table_with_schema NVARCHAR(250) = QUOTENAME(@schema_name) + '.' + QUOTENAME(@table_name)
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @proc_name nvarchar(128) = 'sp_collate_columns_for_CETAS';
    DECLARE @table_sql nvarchar(300);

  BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'table_with_schema', @table_with_schema;

    IF OBJECT_ID('tempdb..#cols') IS NOT NULL
        DROP TABLE #cols;

    /*
        Collect column metadata:
        - cname      → column name
        - rownum     → iteration index
        - ischar     → character-based datatypes (varchar, nvarchar, char, nchar, sysname)
        - isuniqueid → uniqueidentifier type
    */
    SELECT
        [column].[name] AS [cname],
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [rownum],
        CASE
            WHEN [type].[name] IN ('varchar', 'nvarchar', 'char', 'sysname', 'nchar') THEN 1
            ELSE 0
        END AS [ischar],
        CASE
            WHEN [type].[name] IN ('uniqueidentifier') THEN 1
            ELSE 0
        END AS [isuniqueid]
    INTO #cols
    FROM [sys].[columns] AS [column]
    INNER JOIN [sys].[types] AS [type] ON [column].[user_type_id] = [type].[user_type_id]
    WHERE [column].[object_id] = OBJECT_ID(@table_with_schema);

    SET @sql = 'SELECT'
    SELECT @table_row_count = COUNT(*) FROM #cols;

    -- Iterate columns to build the expression for each one
    WHILE (@row_id <= @table_row_count)
        BEGIN
            SELECT
                @col = [cname],
                @isChar = [ischar],
                @isUniqueID = [isuniqueid]
            FROM #cols
            WHERE [rownum] = @row_id;

            /*
                CETAS-specific conversions:
                ------------------------------------------------------
                CHAR/NCHAR/VARCHAR/NVARCHAR/sysname:
                    - Empty string ('') becomes 0x00 to avoid losing it during CETAS.
                    - Non-empty values are converted to VARBINARY(MAX).
                    - Binary conversion is applied to preserve UTF-8 encoded strings
                    because external tables do not preserve UTF-8 reliably.

                uniqueidentifier:
                    - Convert to CHAR(255) + fixed collation for stable representation.

                Other datatypes:
                    - Passed through unchanged.
            */
            IF @isChar = 1
                SET @sql = @sql + '
                    CASE
                        WHEN ' + QUOTENAME(@col) + ' = '''' THEN 0x00
                        ELSE CAST(' + QUOTENAME(@col) + ' AS VARBINARY(MAX))
                    END AS ' + QUOTENAME(@col) + ',';
            ELSE
                BEGIN
                    IF @isUniqueID = 1
                        SET @sql = @sql + ' CONVERT(CHAR(255), ' + QUOTENAME(@col) + ') COLLATE Latin1_General_100_CI_AS_SC AS ' + QUOTENAME(@col) + ',';
                    ELSE
                        SET @sql = @sql + ' ' + QUOTENAME(@col) + ' AS ' + QUOTENAME(@col) + ',';
                END

            SET @row_id = @row_id + 1;
        END

    SET @sql = SUBSTRING(@sql, 0, LEN(@sql)) + ' FROM ' + @table_with_schema
    SET @table_sql = @table_with_schema +'_sql';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, @table_sql, @sql;
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

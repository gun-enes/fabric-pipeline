/*
    Description:
        Generates CREATE TABLE definition statement for a given table including:
        - Column definitions with proper data types and nullability
        - Distribution policy (HASH/REPLICATE/ROUND_ROBIN)
        - Index type (CLUSTERED COLUMNSTORE/HEAP)
    Author:
        extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_generate_table_definition]
    (@schema_name NVARCHAR(43), @table_name NVARCHAR(200), @table_rename NVARCHAR(200), @table_definition NVARCHAR(MAX) OUTPUT)
AS
BEGIN
    DECLARE
        @dist NVARCHAR(4000),
        @create_table_name_definition NVARCHAR(500),
        @index NVARCHAR(200),
        @log_detail_group uniqueidentifier = NEWID(),
        @proc_name nvarchar(128) = 'sp_infra_generate_table_definition';

  BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'schema_name', @schema_name;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'table_name', @table_name;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'table_rename', @table_rename;
    SELECT @create_table_name_definition = '
    IF OBJECT_ID(''' + QUOTENAME(@schema_name) + '.' + QUOTENAME(@table_rename) + ''') IS NOT NULL
    BEGIN
        DROP TABLE ' + QUOTENAME(@schema_name) + '.' + QUOTENAME(@table_rename) + ';
    END
    CREATE TABLE [' + @schema_name + '].[' + @table_rename + ']';

    -- 1. Generate Column definition
    WITH [information_schema_columns] AS (
        SELECT
            [TABLE_SCHEMA] AS [table_schema],
            [TABLE_NAME] AS [table_name],
            [COLUMN_NAME] AS [column_name],
            [DATETIME_PRECISION] AS [datetime_precision]
        FROM [INFORMATION_SCHEMA].[COLUMNS]
        WHERE
            [TABLE_SCHEMA] = @schema_name
            AND [TABLE_NAME] = @table_name
    )

    SELECT
        @table_definition
        = '(' + CHAR(10)
        + STRING_AGG(
            '    [' + [columns].[name] + '] '
            + '[' + UPPER([types].[name]) + ']' +
            + CASE
                WHEN [types].[name] IN ('varchar', 'char', 'varbinary', 'binary')
                    THEN
                        '('
                        + CASE
                            WHEN [columns].[max_length] = -1 THEN 'MAX'
                            ELSE CAST([columns].[max_length] AS VARCHAR)
                        END + ')'

                WHEN [types].[name] IN ('nvarchar', 'nchar')
                    THEN
                        '('
                        + CASE
                            WHEN [columns].[max_length] = -1 THEN 'MAX'
                            ELSE CAST([columns].[max_length] / 2 AS VARCHAR)
                        END + ')'

                WHEN [types].[name] IN ('decimal', 'numeric')
                    THEN
                        '(' + CAST([columns].[precision] AS VARCHAR) + ',' + CAST([columns].[scale] AS VARCHAR) + ')'

                WHEN [types].[name] IN ('datetime2', 'datetimeoffset', 'time')
                    THEN
                        '(' + CAST(
                            COALESCE([information_schema_columns].[datetime_precision], [columns].[scale])
                            AS VARCHAR
                        ) + ')'

                ELSE ''
            END
            + CASE
                WHEN [columns].[is_nullable] = 0 THEN ' NOT NULL'
                ELSE ' NULL'
            END,
            ',' + CHAR(10)
        ) + CHAR(10) + ')'
    FROM [sys].[tables] AS [tables]
    INNER JOIN [sys].[schemas] AS [schemas] ON [tables].[schema_id] = [schemas].[schema_id]
    INNER JOIN [sys].[columns] AS [columns] ON [tables].[object_id] = [columns].[object_id]
    INNER JOIN [sys].[types] AS [types] ON [columns].[user_type_id] = [types].[user_type_id]
    LEFT JOIN [information_schema_columns]
        ON
            [schemas].[name] = [information_schema_columns].[table_schema]
            AND [tables].[name] = [information_schema_columns].[table_name]
            AND [columns].[name] = [information_schema_columns].[column_name]
    WHERE
        [schemas].[name] = @schema_name
        AND [tables].[name] = @table_name
    GROUP BY [schemas].[name], [tables].[name];

    -- 2. Append Distribution
    SELECT
        @dist
        = CASE [table_dist_properties].[distribution_policy_desc]
            WHEN 'HASH'
                THEN
                    'DISTRIBUTION = HASH ([' + [columns].[name] + '])'
            ELSE
                'DISTRIBUTION = ' + [table_dist_properties].[distribution_policy_desc]
        END
    FROM [sys].[pdw_table_distribution_properties] AS [table_dist_properties]
    INNER JOIN [sys].[tables] AS [tables] ON [table_dist_properties].[object_id] = [tables].[object_id]
    LEFT JOIN [sys].[pdw_column_distribution_properties] AS [column_dist_properties]
        ON [table_dist_properties].[object_id] = [column_dist_properties].[object_id] AND [column_dist_properties].[distribution_ordinal] = 1
    LEFT JOIN [sys].[columns] AS [columns]
        ON [column_dist_properties].[object_id] = [columns].[object_id] AND [column_dist_properties].[column_id] = [columns].[column_id]
    WHERE [tables].[name] = @table_name
    AND SCHEMA_NAME([tables].[schema_id]) = @schema_name;

    -- 3. Append Index type
    SELECT
        @index
        = CASE [i].[type_desc]
            WHEN 'CLUSTERED COLUMNSTORE'
                THEN 'CLUSTERED COLUMNSTORE INDEX'
            WHEN 'HEAP'
                THEN 'HEAP'
            WHEN 'CLUSTERED'
                THEN
                    'CLUSTERED INDEX ('
                    + STRING_AGG(
                        '[' + [c].[name] COLLATE DATABASE_DEFAULT + ']'
                        + CASE WHEN [ic].[is_descending_key] = 1 THEN ' DESC' ELSE ' ASC' END,
                        ', '
                    ) WITHIN GROUP (
                        ORDER BY [ic].[key_ordinal]
                    )
                    + ')'
            ELSE [i].[type_desc]
        END
    FROM [sys].[indexes] AS [i]
    INNER JOIN [sys].[tables] AS [tables]
        ON [i].[object_id] = [tables].[object_id]
    LEFT JOIN [sys].[index_columns] AS [ic]
        ON
            [i].[object_id] = [ic].[object_id]
            AND [i].[index_id] = [ic].[index_id]
    LEFT JOIN [sys].[columns] AS [c]
        ON
            [ic].[object_id] = [c].[object_id]
            AND [ic].[column_id] = [c].[column_id]
    WHERE
        [i].[index_id] < 2
        AND [tables].[name] = @table_name
        AND SCHEMA_NAME([tables].[schema_id]) = @schema_name
    GROUP BY [i].[type_desc];

    -- 4. Final generate CREATE TABLE sql
    SET
        @table_definition = @create_table_name_definition
        + @table_definition + CHAR(10)
        + 'WITH (' + CHAR(10)
        + '    ' + @dist + ',' + CHAR(10)
        + '    ' + @index + CHAR(10)
        + ');';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'table_definition', @table_definition;
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
END;

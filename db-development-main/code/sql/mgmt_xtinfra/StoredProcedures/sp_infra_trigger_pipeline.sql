/*
Description:
Creates an external table to fire a Synapse trigger.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_trigger_pipeline] (
    @workspace_name NVARCHAR(10),
    @trigger_name NVARCHAR(120)
)
AS
BEGIN
    DECLARE @proc_name NVARCHAR(128) = 'sp_infra_trigger_pipeline';
    DECLARE @log_detail_group UNIQUEIDENTIFIER = NEWID();

    DECLARE @data_source_name NVARCHAR(128) = 'mgmt-ext';

    DECLARE @location NVARCHAR(122) = '/' + @trigger_name + '/';
    DECLARE @ext_table_name NVARCHAR(128) = QUOTENAME(@workspace_name) + '.trigger_' + @trigger_name;
    DECLARE @minimum_seconds_global_config_key NVARCHAR(130) = @trigger_name + '_minimum_seconds_between_triggers'
    DECLARE @minimum_seconds_between_triggers INT = 600;
    DECLARE @last_pipeline_execution_time DATETIME;

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workspace_name', @workspace_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'trigger_name', @trigger_name;

        DECLARE @sql_stmt NVARCHAR(512);
        DECLARE
        @create_table_sql_stmt NVARCHAR(512) = N'CREATE EXTERNAL TABLE '
        + @ext_table_name
        + ' WITH (
                LOCATION = ''' + @location + '''
                ,DATA_SOURCE = ' + QUOTENAME(@data_source_name) + '
                ,FILE_FORMAT = SynapseParquetFormat
            ) AS
            SELECT GETDATE() AS execution_time;';

        IF
            EXISTS (
                SELECT 1
                FROM sys.external_data_sources
                WHERE [name] = @data_source_name
            )
            BEGIN
                -- Set minimum_seconds_between_triggers to value in config if it exist in the config,
                -- it is left as 60 otherwise
                IF
                    EXISTS (
                        SELECT 1
                        FROM [mgmt_xtinfra].[infra_global_config]
                        WHERE [key] = @minimum_seconds_global_config_key
                    )
                    SELECT @minimum_seconds_between_triggers = [value]
                    FROM [mgmt_xtinfra].[infra_global_config]
                    WHERE [key] = @minimum_seconds_global_config_key

                -- First time running
                IF OBJECT_ID(@ext_table_name, 'ET') IS NULL
                    EXECUTE sp_executesql @create_table_sql_stmt;
                ELSE
                    BEGIN
                        SET
                            @sql_stmt = N'SELECT TOP 1 @last_pipeline_execution_time = [execution_time] FROM '
                            + @ext_table_name
                            + ' ORDER BY [execution_time] DESC;';
                        EXEC sp_executesql
                            @sql_stmt, N'@last_pipeline_execution_time DATETIME OUT', @last_pipeline_execution_time out;

                        -- Pipeline has not yet deleted the file.
                        -- Meaning that it has not yet reached the step to read from db tables either
                        IF @last_pipeline_execution_time IS NOT NULL
                            BEGIN
                                PRINT 'Checking last pipeline execution time..';
                                -- More time than expected has passed,
                                -- which might mean last run failed at some point before deleting the file
                                -- Triggering pipeline again as a safety measure
                                IF
                                    DATEDIFF(SECOND, @last_pipeline_execution_time, GETDATE())
                                    > @minimum_seconds_between_triggers
                                    BEGIN
                                        PRINT 'Exceeded minimum time between pipeline runs, triggering pipeline.';

                                        SET @sql_stmt = N'DROP EXTERNAL TABLE ' + @ext_table_name + ';';
                                        EXEC sp_executesql @sql_stmt;

                                        EXECUTE sp_executesql @create_table_sql_stmt;
                                    END
                                -- It is expected that the pipeline has not reached the step where it deletes the file.
                                -- Meaning it should not have read the db tables yet, so we can skip triggering the pipeline
                                ELSE
                                    PRINT 'Did not exceed minimum time between pipeline runs, not triggering pipeline.';
                            END
                        -- Pipeline has deleted the file. This means that it probably already read from the db tables.
                        -- We need to trigger it again so that it can proccess the new entries in the tables
                        ELSE
                            BEGIN
                                PRINT 'Last pipeline run ended, triggering pipeline.';

                                SET @sql_stmt = N'DROP EXTERNAL TABLE ' + @ext_table_name + ';';
                                EXEC sp_executesql @sql_stmt;

                                EXECUTE sp_executesql @create_table_sql_stmt;
                            END
                    END
            END
        ELSE
            PRINT 'External data source ' + @data_source_name + ' does not exist, not triggering pipeline.'

        -- complete log
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'success';
    END TRY
    BEGIN CATCH
        --- add log entry for our job
        DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @error_severity INT = ERROR_SEVERITY();
        DECLARE @error_state INT = ERROR_STATE();

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_message', @error_message;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_severity', @error_severity;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_state', @error_state;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'failure';

        --Intentionally not throwing as an exception in this stored procedure should not effect the caller
        --THROW;
    END CATCH
END

/*
Description: Creates expanded JSON Schedules to be consumed by the Trigger API

Author:
extern.agarwal_shikar@allianz.com
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_create_json_schedules] AS
BEGIN
    DECLARE @proc_name nvarchar(128) = 'sp_infra_create_json_schedules';
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @key nvarchar(100);
    DECLARE @hour int;
    DECLARE @trg_dispatch_json nvarchar(MAX);
    BEGIN TRY

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        IF OBJECT_ID('tempdb..#temp_json_schedule') IS NOT NULL
            DROP TABLE [#temp_json_schedule];

        -- Temporary table to store the JSON output and trigger name
        CREATE TABLE [#temp_json_schedule]
        (
            [key] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
            [trigger_name] [nvarchar](255) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
            [json_output] [nvarchar](4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL
        );

        WITH CTE AS (
            SELECT
                [key],
                [schedule_action],
                [schedule_time],
                [created_at],
                CASE
                    WHEN schedule_action = 'start' THEN 'pl_root_infra_maintenance_end'
                    WHEN schedule_action = 'stop' THEN 'pl_root_infra_maintenance_start'
                    WHEN schedule_action = 'gatherstats_start' THEN 'pl_root_infra_gatherstats_terminate'
                    ELSE 'invalid-action'
                END AS referenceName,
                CASE
                    WHEN schedule_action = 'start' and requestor = 'microsoft' THEN 'trg_ms_maintenance_stop_' +
                        CONVERT(nvarchar(10), DATEPART(YEAR, schedule_time)) + '_' +
                        RIGHT('0' + CONVERT(nvarchar(2), DATEPART(MONTH, schedule_time)), 2) + '_' +
                        RIGHT('0' + CONVERT(nvarchar(2), DATEPART(DAY, schedule_time)), 2)
                    WHEN schedule_action = 'stop' and requestor = 'microsoft' THEN 'trg_ms_maintenance_start_' +
                        CONVERT(NVARCHAR(10), DATEPART(YEAR, schedule_time)) + '_' +
                        RIGHT('0' + CONVERT(nvarchar(2), DATEPART(MONTH, schedule_time)), 2) + '_' +
                        RIGHT('0' + CONVERT(nvarchar(2), DATEPART(DAY, schedule_time)), 2)
                    WHEN schedule_action = 'start' THEN 'trg_maintenance_stop_' +
                        CONVERT(nvarchar(10), DATEPART(YEAR, schedule_time)) + '_' +
                        RIGHT('0' + CONVERT(nvarchar(2), DATEPART(MONTH, schedule_time)), 2) + '_' +
                        RIGHT('0' + CONVERT(nvarchar(2), DATEPART(DAY, schedule_time)), 2)
                    WHEN schedule_action = 'stop' THEN 'trg_maintenance_start_' +
                        CONVERT(NVARCHAR(10), DATEPART(YEAR, schedule_time)) + '_' +
                        RIGHT('0' + CONVERT(nvarchar(2), DATEPART(MONTH, schedule_time)), 2) + '_' +
                        RIGHT('0' + CONVERT(nvarchar(2), DATEPART(DAY, schedule_time)), 2)
                    WHEN schedule_action = 'gatherstats_start' THEN
                        'trg_stats_' + [key] + '_' +
                        CONVERT(NVARCHAR(10), DATEPART(YEAR, schedule_time)) + '_' +
                        RIGHT('0' + CONVERT(nvarchar(2), DATEPART(MONTH, schedule_time)), 2) + '_' +
                        RIGHT('0' + CONVERT(nvarchar(2), DATEPART(DAY, schedule_time)), 2)
                    ELSE 'invalid-action'
                END AS trigger_name,
                CONVERT(nvarchar(10), DATEADD(DAY, -1, schedule_time), 126) + 'T23:59:00Z' AS startTime,
                CONVERT(nvarchar(10), schedule_time, 126) + 'T23:59:59Z' AS endTime,
                DATEPART(MINUTE, schedule_time) AS minutes,
                DATEPART(HOUR, schedule_time) AS hours
            FROM [mgmt_xtinfra].[infra_expanded_schedule]
            WHERE
                CONVERT(DATE, schedule_time) <= CONVERT(DATE, DATEADD(DAY, 7, GETDATE()))
        )
        INSERT INTO [#temp_json_schedule] ([key], [trigger_name], [json_output])
        SELECT
            [key],
            trigger_name,
            '{
                "properties": {
                    "annotations": [],
                    "runtimeState": "Started",
                    "pipelines": [
                        {
                            "pipelineReference": {
                            "referenceName": "' + referenceName + '",
                            "type": "PipelineReference"
                            }
                        }
                    ],
                    "type": "ScheduleTrigger",
                    "typeProperties": {
                        "recurrence": {
                            "frequency": "Day",
                            "interval": 1,
                            "startTime": "' + startTime + '",
                            "endTime": "' + endTime + '",
                            "timeZone": "UTC",
                            "schedule": {
                                "minutes": [
                                    ' + CAST(minutes AS nvarchar(2)) + '
                                ],
                                "hours": [
                                    ' + CAST(hours AS nvarchar(2)) + '
                                ]
                            }
                        }
                    }
                }
            }' AS json_output
        FROM CTE;

        SET DATEFIRST 1;
        SELECT TOP(1)
        @key = [key],
        @hour = DATEPART(hour, [schedule_time])
        FROM [mgmt_xtinfra].[infra_expanded_schedule]
        WHERE [schedule_action] = 'start'
        AND CONVERT(DATE, schedule_time) <= CONVERT(DATE, DATEADD(DAY, 7, GETDATE()))
        AND (DATEPART(weekday, schedule_time) = 2 OR DATEPART(weekday, schedule_time) = 5)
        ORDER BY [schedule_time]

        SET @key = ISNULL(@key, 'trg_dispatch_default_schedule');
        SET @hour = ISNULL(@hour, 12);
        SET @trg_dispatch_json =
        '{
            "properties": {
                "annotations": [],
                "runtimeState": "Started",
                "pipelines": [
                    {
                        "pipelineReference": {
                            "referenceName": "pl_root_infra_create_downtime_triggers",
                            "type": "PipelineReference"
                        }
                    }
                ],
                "type": "ScheduleTrigger",
                "typeProperties": {
                    "recurrence": {
                        "frequency": "Week",
                        "interval": 1,
                        "startTime": "' + CAST(FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ssZ') AS nvarchar(50)) + '",
                        "timeZone": "UTC",
                        "schedule": {
                            "minutes": [
                                30
                            ],
                            "hours": [
                                ' + CAST(@hour AS nvarchar(2)) + '
                            ],
                            "weekDays": [
                                "Tuesday",
                                "Friday"
                            ]
                        }
                    }
                }
            }
        }';

        INSERT INTO [#temp_json_schedule] ([key], [trigger_name], [json_output])
        VALUES (@key, 'trg_dispatch', @trg_dispatch_json);

        -- Select the results from the temporary table
        SELECT [key],[trigger_name],[json_output]
        FROM [#temp_json_schedule]
        where [trigger_name] <> 'invalid-action';

        -- Drop table is intentionally removed as #temp_json_schedule is required in tests and temporary tables are dropped when session ends

        -- complete log
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'success';

    END TRY
    BEGIN CATCH
        --- add log entry for our job
        DECLARE @error_message nvarchar(4000) = ERROR_MESSAGE();
        DECLARE @error_severity int = ERROR_SEVERITY();
        DECLARE @error_state int = ERROR_STATE();

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_message', @error_message;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_severity', @error_severity;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_state', @error_state;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'failure';
        --- then throw again to forward error
        THROW;
    END CATCH
END
GO

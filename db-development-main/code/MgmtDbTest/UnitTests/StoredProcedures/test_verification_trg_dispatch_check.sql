--Check if trg_dispatch json is generated correctly
CREATE PROCEDURE [UnitTests].[test_verification_trg_dispatch_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_trg_dispatch_check')
    EXEC [mgmt_xtinfra].[sp_infra_create_json_schedules];

    DECLARE @json_check INT;
    DECLARE @json_output NVARCHAR(MAX);
    DECLARE @frequency NVARCHAR(50);
    DECLARE @minute NVARCHAR(50);
    DECLARE @hour NVARCHAR(50);
    DECLARE @days NVARCHAR(50);
    DECLARE @maintenance_hour INT;
    DECLARE @maintenance_trg NVARCHAR(MAX);
    DECLARE @trg_date NVARCHAR(10);

    SET DATEFIRST 1;

    SELECT @json_output = [json_output]
    FROM #temp_json_schedule
    WHERE [trigger_name] = 'trg_dispatch'

    SET @json_check = ISJSON(@json_output)
    -- Check json format is valid
    EXEC [tSQLt_synapse].[AssertEqualsInt] @json_check, 1

    SELECT
        @frequency = [Frequency],
        @minute = [Minutes],
        @hour = [Hours]
    FROM
        OPENJSON (@json_output)
        WITH (
            [Minutes] INT '$.properties.typeProperties.recurrence.schedule.minutes[0]',
            [Hours] INT '$.properties.typeProperties.recurrence.schedule.hours[0]',
            [Frequency] NVARCHAR(50) '$.properties.typeProperties.recurrence.frequency'
        )

    SELECT @days = STRING_AGG(CAST([Second_json].[value] AS NVARCHAR(MAX)) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8, ', ')
    FROM
        OPENJSON (@json_output)
        WITH (
            [Dates] NVARCHAR(MAX) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 '$.properties.typeProperties.recurrence.schedule.weekDays' AS JSON
        ) AS [First_json]
    CROSS APPLY OPENJSON([First_json].[Dates], '$') AS [Second_json]

    -- Check if frequency is set correctly for trg_dispatch
    EXEC [tSQLt_synapse].[AssertEqualsString] @frequency, 'Week'
    -- Check if minute is set correctly for trg_dispatch
    EXEC [tSQLt_synapse].[AssertEqualsInt] @minute, 30
    -- Check if weekDays is set correctly for trg_dispatch
    EXEC [tSQLt_synapse].[AssertEqualsString] @days, 'Tuesday, Friday'

    SELECT TOP (1)
        @maintenance_trg = [json_output],
        @trg_date = REPLACE(RIGHT([trigger_name], 10), '_', '-')
    FROM #temp_json_schedule
    WHERE
        [trigger_name] LIKE 'trg_maintenance_stop_%'
        AND (
            DATEPART(WEEKDAY, CAST(REPLACE(RIGHT([trigger_name], 10), '_', '-') AS DATE)) = 2
            OR DATEPART(WEEKDAY, CAST(REPLACE(RIGHT([trigger_name], 10), '_', '-') AS DATE)) = 5
        )
    ORDER BY [trigger_name]

    IF (@maintenance_trg IS NOT NULL AND @maintenance_trg <> '')
        BEGIN
            SELECT @maintenance_hour = [maintenance_hour]
            FROM
                OPENJSON (@maintenance_trg)
                WITH (
                    [maintenance_hour] INT '$.properties.typeProperties.recurrence.schedule.hours[0]'
                )
            PRINT (
                'There exists a trg_maintenance_stop trigger scheduled for '
                + @trg_date
                + ' to hour: '
                + CAST(@maintenance_hour AS NVARCHAR(2))
            );
            -- Check if hour is set correctly for trg_dispatch
            EXEC [tSQLt_synapse].[AssertEqualsInt] @maintenance_hour, @hour;
        END
    ELSE
        BEGIN
            PRINT ('trg_dispatch is scheduled to default hour');
            -- Check if hour is set correctly for trg_dispatch
            EXEC [tSQLt_synapse].[AssertEqualsInt] 12, @hour;
        END
END;
GO

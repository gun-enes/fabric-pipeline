--Check if schedule objects are older than an hour and related expanded schedule is not created
CREATE PROCEDURE [UnitTests].[test_verification_infra_schedule_object_processed_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_infra_schedule_object_processed_check');

    DECLARE @startHour INT, @stopHour INT;
    CREATE TABLE [UnitTests].[UnprocessedSchedules]
    (
        [key] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
        [crontab] [nvarchar](305) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
        [hour] [int] NOT NULL,
        [day_of_month] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
        [month] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
        [day_of_week] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
        [schedule_action] [nvarchar](100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
        [priority] [int] NOT NULL,
        [created_at] [datetime] NOT NULL,
        [requestor] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
        [rank] INT NULL
    )

    -- Order start and stop schedules to get highest priority and earliest hour
    SELECT *,
        RANK() OVER (PARTITION BY [schedule].[schedule_action] ORDER BY [schedule].[priority] DESC, [schedule].[hour] ASC) AS rnk
    INTO [#MaxPriorityCTE]
    FROM [mgmt_xtinfra].[infra_schedule] AS schedule
    WHERE [schedule_action] <> 'gatherstats_start'
    AND GETDATE() > DATEADD(hour, 1, [schedule].[created_at])
    AND [schedule].[month] = '*'
    AND [schedule].[day_of_month] = '*'
    AND [schedule].[day_of_week] IN ('*', '1-5')

    -- Insert unprocessed gatherstats schedules
    INSERT INTO [UnitTests].[UnprocessedSchedules]
    SELECT *, NULL
    FROM [mgmt_xtinfra].[infra_schedule] AS schedule
    WHERE GETDATE() > DATEADD(hour, 1, [schedule].[created_at])
    AND [schedule].[month] = '*'
    AND [schedule].[day_of_month] = '*'
    AND [schedule].[day_of_week] IN ('*', '1-5')
    AND [schedule].[schedule_action] = 'gatherstats_start'
    AND [schedule].[key] NOT IN (
        SELECT DISTINCT [exp_schedule].[key]
        FROM [mgmt_xtinfra].[infra_expanded_schedule] AS [exp_schedule]
        WHERE [schedule].[created_at] < [exp_schedule].[created_at]
    )

    SELECT TOP(1)
    @startHour = [hour]
    FROM [#MaxPriorityCTE]
    WHERE [rnk] = 1
    AND [schedule_action] = 'start'

    SELECT TOP(1)
    @stopHour = [hour]
    FROM [#MaxPriorityCTE]
    WHERE [rnk] = 1
    AND [schedule_action] = 'stop'

    -- If start and stop schedule with highest priority are at the same hour, one of them should be expanded
    IF (@startHour = @stopHour)
        BEGIN
            IF NOT EXISTS (
                SELECT *
                FROM [#MaxPriorityCTE] AS maxp
                INNER JOIN [mgmt_xtinfra].[infra_expanded_schedule] AS [exp]
                ON [exp].[key] = [maxp].[key]
                WHERE [maxp].[rnk] = 1
                AND [maxp].[created_at] < [exp].[created_at]
            )
            BEGIN
                INSERT INTO [UnitTests].[UnprocessedSchedules]
                SELECT *
                FROM [#MaxPriorityCTE] AS maxp
                WHERE [maxp].[rnk] = 1
            END
        END
    ELSE
        BEGIN
            -- Insert unprocessed start schedule with highest priortiy
            IF NOT EXISTS (
                SELECT *
                FROM [#MaxPriorityCTE] AS maxp
                INNER JOIN [mgmt_xtinfra].[infra_expanded_schedule] AS [exp]
                ON [exp].[key] = [maxp].[key]
                WHERE [maxp].[rnk] = 1
                AND [maxp].[created_at] < [exp].[created_at]
                AND [maxp].[schedule_action] = 'start'
            )
            BEGIN
                INSERT INTO [UnitTests].[UnprocessedSchedules]
                SELECT *
                FROM [#MaxPriorityCTE] AS maxp
                WHERE [maxp].[rnk] = 1
                AND [maxp].[schedule_action] = 'start'
            END
            -- Insert unprocessed stop schedule with highest priortiy
            IF NOT EXISTS (
                SELECT *
                FROM [#MaxPriorityCTE] AS maxp
                INNER JOIN [mgmt_xtinfra].[infra_expanded_schedule] AS [exp]
                ON [exp].[key] = [maxp].[key]
                WHERE [maxp].[rnk] = 1
                AND [maxp].[created_at] < [exp].[created_at]
                AND [maxp].[schedule_action] = 'stop'
            )
            BEGIN
                INSERT INTO [UnitTests].[UnprocessedSchedules]
                SELECT *
                FROM [#MaxPriorityCTE] AS maxp
                WHERE [maxp].[rnk] = 1
                AND [maxp].[schedule_action] = 'stop'
            END
        END

    PRINT ('Schedules that are not processed within 1 hour are given below')
    -- Table should be empty if all schedules are processed within 1 hour
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.UnprocessedSchedules'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_infra_schedule_object_processed_check]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_infra_schedule_object_processed_check')
    DROP TABLE [UnitTests].[UnprocessedSchedules]
END;
GO

CREATE PROCEDURE [UnitTests].[sp_testutil_create_gatherstats_schedule]
(
    @key NVARCHAR(100),
    @hour INT,
    @day_of_month NVARCHAR(100),
    @month NVARCHAR(100),
    @day_of_week NVARCHAR(100),
    @priority INT,
    @stats_type NVARCHAR(6),
    @stats_pct INT,
    @schema NVARCHAR(43)
)
AS
BEGIN
    -- Local variables
    DECLARE
        @requestor NVARCHAR(128) = SESSION_USER,
        @now DATETIME = GETDATE(),
        @crontab NVARCHAR(305),
        @base_date DATE = CAST(GETDATE() AS DATE),
        @target_date DATE,
        @day_counter INT = 0,
        @schedule_time DATETIME,
        @created_at DATETIME;

    SET @crontab = '0 ' + CAST(@hour AS NVARCHAR(2)) + ' '
                         + @day_of_month + ' '
                         + @month + ' '
                         + @day_of_week;

    -- Insert into [infra_schedule]
    INSERT INTO [mgmt_xtinfra].[infra_schedule]
        ([key], [crontab], [hour], [day_of_month], [month],
         [day_of_week], [schedule_action], [priority], [created_at], [requestor])
    VALUES
        (@key, @crontab, @hour, @day_of_month, @month,
         @day_of_week, 'gatherstats_start', @priority, @now, @requestor);

    -- Insert into [infra_gatherstats_schedule_detail]
    INSERT INTO [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
        ([infra_schedule_key], [stats_type], [stats_pct], [schema_name], [created_at], [requestor])
    VALUES
        (@key, @stats_type, @stats_pct, @schema, @now, @requestor);

    WHILE @day_counter < 5
    BEGIN
        SET @target_date = DATEADD(DAY, @day_counter, @base_date);
        SET @schedule_time = DATEADD(HOUR, @hour, CAST(@target_date AS DATETIME));
        SET @created_at = GETDATE();

        -- Insert into [infra_expanded_schedule]
        INSERT INTO [mgmt_xtinfra].[infra_expanded_schedule]
            ([key], [schedule_action], [schedule_time], [created_at])
        VALUES
            (@key, 'gatherstats_start', @schedule_time, @created_at);

        SET @day_counter += 1;
    END;
END;
GO

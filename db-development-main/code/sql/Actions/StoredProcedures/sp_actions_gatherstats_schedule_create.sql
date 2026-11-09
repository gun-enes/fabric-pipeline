CREATE PROCEDURE [Actions].[sp_actions_gatherstats_schedule_create]
    @key [NVARCHAR](100),
    @hour [INT],
    @day_of_month [NVARCHAR](100),
    @month [NVARCHAR](100),
    @day_of_week [NVARCHAR](100),
    @priority [INT],
    @stats_type [NVARCHAR](6),
    @stats_pct [INT],
    @schema_name [NVARCHAR](43)
    AS
BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_gatherstats_schedule_create]
        @key,
        @hour,
        @day_of_month,
        @month,
        @day_of_week,
        @priority,
        'Actions',
        @stats_type,
        @stats_pct,
        @schema_name;
END
GO

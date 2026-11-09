CREATE PROCEDURE [Actions].[sp_actions_schedule_create]
    @key NVARCHAR(100),
    @schedule_action NVARCHAR(100),
    @hour INT,
    @day_of_month NVARCHAR(100),
    @month NVARCHAR(100),
    @day_of_week NVARCHAR(100),
    @priority INT
AS
BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_schedule_create]
        @key,
        @schedule_action,
        @hour,
        @day_of_month,
        @month,
        @day_of_week,
        @priority,
        'Actions';
END

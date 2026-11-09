CREATE VIEW [Actions].[v_schedule]
AS
SELECT
    [key],
    [hour],
    [day_of_month],
    [month],
    [day_of_week],
    [schedule_action],
    [priority],
    [created_at]
FROM [mgmt_xtinfra].[infra_schedule];

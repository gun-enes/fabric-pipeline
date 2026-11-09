CREATE VIEW [Actions].[v_expanded_schedule]
AS
SELECT
    [key],
    [schedule_action],
    [schedule_time],
    [created_at]
FROM [mgmt_xtinfra].[infra_expanded_schedule] WHERE [schedule_time] >= GETDATE();

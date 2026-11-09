CREATE VIEW [Actions].[v_expanded_gatherstats_schedule]
AS
SELECT
    A.[key],
    A.[schedule_action],
    A.[schedule_time],
    A.[created_at],
    B.[stats_type],
    B.[stats_pct],
    B.[schema_name]
FROM [mgmt_xtinfra].[infra_expanded_schedule] A,
[mgmt_xtinfra].[infra_gatherstats_schedule_detail] B
WHERE A.[key] = B.[infra_schedule_key]
AND A.[schedule_time] >= GETDATE();

CREATE PROCEDURE [Actions].[sp_actions_workloadclassifier_order_create_or_update]
    @classifier_name NVARCHAR(128),
    @workload_group NVARCHAR(128),
    @member_name NVARCHAR(128),
    @wlm_label NVARCHAR(255),
    @wlm_context NVARCHAR(255),
    @start_hour INT,
    @start_minute INT,
    @end_hour INT,
    @end_minute INT,
    @importance NVARCHAR(128)
AS
BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_order_create_or_update]
        @classifier_name,
        @workload_group,
        @member_name,
        @wlm_label,
        @wlm_context,
        @start_hour,
        @start_minute,
        @end_hour,
        @end_minute,
        @importance,
        'Actions';
END

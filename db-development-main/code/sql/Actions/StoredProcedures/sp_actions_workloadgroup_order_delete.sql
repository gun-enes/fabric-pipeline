CREATE PROCEDURE [Actions].[sp_actions_workloadgroup_order_delete]
    @group_name NVARCHAR(128)
AS
BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_order_delete]
        @group_name,
        'Actions';
END

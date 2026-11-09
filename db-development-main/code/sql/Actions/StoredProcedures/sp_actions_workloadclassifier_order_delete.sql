CREATE PROCEDURE [Actions].[sp_actions_workloadclassifier_order_delete]
    @classifier_name NVARCHAR(128)
AS
BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_order_delete]
        @classifier_name,
        'Actions';
END

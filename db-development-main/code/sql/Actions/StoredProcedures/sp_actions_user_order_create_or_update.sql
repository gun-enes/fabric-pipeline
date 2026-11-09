CREATE PROCEDURE [Actions].[sp_actions_user_order_create_or_update]
    @user_name NVARCHAR(128)
AS
BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_user_order_create_or_update]
        @user_name,
        'Actions';
END

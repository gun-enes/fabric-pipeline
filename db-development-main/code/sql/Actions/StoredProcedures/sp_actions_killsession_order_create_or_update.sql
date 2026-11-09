CREATE PROCEDURE [Actions].[sp_actions_killsession_order_create_or_update]
    @session_id NVARCHAR(128)
AS
BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_killsession_order_create_or_update]
        @session_id,
        'Actions';
END

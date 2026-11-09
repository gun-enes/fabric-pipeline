CREATE PROCEDURE [Actions].[sp_actions_gatherstats_schedule_delete]
    @key NVARCHAR(100)
AS
BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_gatherstats_schedule_delete]
        @key,
        'Actions';
END

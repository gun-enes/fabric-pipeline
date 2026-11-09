CREATE PROCEDURE [Actions].[sp_actions_set_config_setting]
    @config_workspace_name [NVARCHAR](10),
    @name [NVARCHAR](128),
    @value [NVARCHAR](128)
    AS
BEGIN
    EXEC [mgmt_xtinfra].[sp_infra_set_config_setting]
        @config_workspace_name,
        @name,
        @value,
        'Actions';
END
GO

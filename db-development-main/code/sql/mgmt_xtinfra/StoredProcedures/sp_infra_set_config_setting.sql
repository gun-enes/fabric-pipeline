/*
Description: Sets a name-value configuration pair for a workspace

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_set_config_setting]
    @config_workspace_name [nvarchar](10),
    @name [nvarchar](128),
    @value [nvarchar](128),
    @workspace_name [nvarchar](10)
AS
BEGIN
    DECLARE @requestor nvarchar(128) = SESSION_USER;
    DECLARE @proc_name nvarchar(128) = 'sp_infra_set_config_setting';

    -- log details
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @now datetime = GETDATE();

    BEGIN TRY

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'config_workspace_name', @config_workspace_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'name', @name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'value', @value;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workspace_name', @workspace_name;

        IF @config_workspace_name IN ('management') OR @config_workspace_name IS NULL
            OR @config_workspace_name NOT IN (SELECT [workspace_name] FROM [mgmt_xtinfra].[infra_workspace_identity_config])
            THROW 50000, 'Invalid config workspace specified.', 1;

        IF @name NOT IN ('on-pause-pipeline-wait-opt-out', 'opt-in-for-ms-maintenance') OR @name IS NULL
            THROW 50000, 'Invalid config name specified.', 1;

        IF @value NOT IN ('enabled', 'disabled') OR @value IS NULL
            THROW 50000, 'Invalid config value specified.', 1;

        IF EXISTS(
            SELECT 1
            FROM [mgmt_xtinfra].[infra_config_settings]
            WHERE [name] = @name
            AND [workspace_name] = @config_workspace_name
        )
        BEGIN
            UPDATE [mgmt_xtinfra].[infra_config_settings]
            SET
                [value] = @value,
                [modified_at] = @now,
                [requestor] = @requestor
            WHERE [workspace_name] = @config_workspace_name
            AND [name] = @name
        END
        ELSE
        BEGIN
            INSERT INTO [mgmt_xtinfra].[infra_config_settings](
                [workspace_name],
                [name],
                [value],
                [created_at],
                [modified_at],
                [requestor]
            )
            VALUES(
                @config_workspace_name,
                @name,
                @value,
                @now,
                @now,
                @requestor
            )
        END

        -- complete log
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'success';

    END TRY
    BEGIN CATCH
        --- add log entry for our job
        DECLARE @error_message nvarchar(4000) = ERROR_MESSAGE();
        DECLARE @error_severity int = ERROR_SEVERITY();
        DECLARE @error_state int = ERROR_STATE();

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_message', @error_message;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_severity', @error_severity;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_state', @error_state;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'failure';
        --- then throw again to forward error
        THROW;
    END CATCH
END
GO

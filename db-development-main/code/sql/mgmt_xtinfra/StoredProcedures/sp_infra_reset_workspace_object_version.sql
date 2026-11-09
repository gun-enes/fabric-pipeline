/*
Description:
This procedure will set workspace and its related objects' version to 0 in infra_object_master table.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_reset_workspace_object_version] (
    @workspace_name [nvarchar](10)
) AS
BEGIN
    -- log details
    DECLARE @proc_name nvarchar(128) = 'sp_infra_reset_workspace_object_version'
    DECLARE @log_detail_group uniqueidentifier = NEWID()

    BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
        @log_detail_group, 'workspace_name', @workspace_name;

        PRINT('Setting workspace: ' + @workspace_name + ' and its objects to version 0');

        UPDATE [mgmt_xtinfra].[infra_object_master]
        SET [version] = 0
        WHERE
            ([name] = @workspace_name AND ([type] = 'workspace' OR [type] = 'schema'))
            OR (
                [type] = 'schemarole'
                AND (
                    [name] = @workspace_name + '-schema-reader'
                    OR [name] = @workspace_name + '-schema-writer'
                    OR [name] = @workspace_name + '-schema-deployer'
                )
            )

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

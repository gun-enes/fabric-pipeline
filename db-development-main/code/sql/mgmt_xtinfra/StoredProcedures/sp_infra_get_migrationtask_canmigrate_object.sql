CREATE PROCEDURE [mgmt_xtinfra].sp_infra_get_migrationtask_canmigrate_object
    @object_type nvarchar(128),
    @object_name nvarchar(128),
    @mode nvarchar(32),
    @migrationtask_id int,
    @can_migrate bit OUTPUT
AS
BEGIN
    DECLARE @current_version int
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @proc_name nvarchar(128) = 'sp_infra_get_migrationtask_canmigrate_object';
  BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'object_type', @object_type;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'object_name', @object_name;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'migrationtask_id', @migrationtask_id;

    EXEC [mgmt_xtinfra].sp_infra_get_object_version @object_type, @object_name, @version = @current_version OUTPUT
    DECLARE @expected_current_version int

    IF @mode = 'upgrade'
        SET @expected_current_version = @migrationtask_id - 1
    ELSE IF @mode = 'downgrade'
        SET @expected_current_version = @migrationtask_id

    IF @current_version = @expected_current_version
        SET @can_migrate = 1
    ELSE
        SET @can_migrate = 0
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'can_migrate', @can_migrate;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'expected_current_version', @expected_current_version;
    -- complete log
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';
  END TRY
  BEGIN CATCH
    DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @error_severity INT = ERROR_SEVERITY();
    DECLARE @error_state INT = ERROR_STATE();
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_message', @error_message
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_severity', @error_severity
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_state', @error_state
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'failure';
    --- then throw again to forward error
    THROW;
  END CATCH
END

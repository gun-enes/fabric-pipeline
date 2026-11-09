/*
Description:
This stored procedure is used to run schema tasks to a specific version.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_schema_run_to_version] (
	@mode [nvarchar](32),
	@start_version int,
	@end_version int,
	@schema_name [nvarchar](42)
) AS
BEGIN
	--- define required variables
	DECLARE @proc_name nvarchar(128) = 'sp_infra_schema_run_to_version'
	DECLARE @log_detail_group uniqueidentifier = NEWID()
	DECLARE @sql_stmt nvarchar(512)

    BEGIN TRY;
	--- assign logging details already here
	EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
	EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'mode', @mode
	EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'start_version', @start_version
	EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'end_version', @end_version
	EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'schema_name', @schema_name

	--- TOOD: VALIDATE VERSIONS parameters
	--- IF MODE is upgrade - end needs to be > start
	--- IF MODE is downgrade - end needs to be < start
	--- IF START is > 0: check for existence

		----------------------------------
		--- BUSINESS LOGIC STARTS HERE ---
		----------------------------------

		PRINT 'Executing schema migration path. mode: ' + @mode + ', start_version: ' + CAST(@start_version AS NVARCHAR(10)) + ', end_version: ' + CAST(@end_version AS NVARCHAR(10)) + ', schema_name: ' + @schema_name

		IF @mode = 'upgrade' OR @mode = 'validate'
		BEGIN
			IF 1 BETWEEN @start_version AND @end_version
				EXEC [mgmt_xtinfra].[sp_infra_schema_migrationtask_0001] @mode, @schema_name
			IF 2 BETWEEN @start_version AND @end_version
				EXEC [mgmt_xtinfra].[sp_infra_schema_migrationtask_0002] @mode, @schema_name
			IF 3 BETWEEN @start_version AND @end_version
				EXEC [mgmt_xtinfra].[sp_infra_schema_migrationtask_0003] @mode, @schema_name
			IF 4 BETWEEN @start_version AND @end_version
				EXEC [mgmt_xtinfra].[sp_infra_schema_migrationtask_0004] @mode, @schema_name
		END
		ELSE IF @mode = 'downgrade'
		BEGIN
			IF 4 BETWEEN @end_version AND @start_version
				EXEC [mgmt_xtinfra].[sp_infra_schema_migrationtask_0004] @mode, @schema_name
			IF 3 BETWEEN @end_version AND @start_version
				EXEC [mgmt_xtinfra].[sp_infra_schema_migrationtask_0003] @mode, @schema_name
			IF 2 BETWEEN @end_version AND @start_version
				EXEC [mgmt_xtinfra].[sp_infra_schema_migrationtask_0002] @mode, @schema_name
			IF 1 BETWEEN @end_version AND @start_version
				EXEC [mgmt_xtinfra].[sp_infra_schema_migrationtask_0001] @mode, @schema_name
		END

		--------------------------------
		--- BUSINESS LOGIC ENDS HERE ---
		--------------------------------

		--- add log entry for our job
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'success';
    END TRY
    BEGIN CATCH
		--- add log entry for our job
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

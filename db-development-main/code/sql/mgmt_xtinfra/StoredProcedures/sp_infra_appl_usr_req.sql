CREATE PROC [mgmt_xtinfra].[sp_infra_appl_usr_req]
     @user_name [VARCHAR](100),@op_name [VARCHAR](100)
AS
BEGIN
	DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @proc_name nvarchar(128) = 'sp_infra_appl_usr_req';

	BEGIN TRY
	 EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
     declare @now [datetime]
	 declare @requestor [VARCHAR](100) = SUSER_SNAME()
     DECLARE @next_sid int = (
	 SELECT
	    	ISNULL(MAX(sid),0)
	 FROM
		[mgmt_xtinfra].[infra_appl_usr_master]) + 1
     set @now=sysdatetime()
     EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'user_name', @user_name;
	 EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'requestor', @requestor;
	 EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'action', @op_name;
	 insert into [mgmt_xtinfra].[infra_appl_usr_master]
	 values (
        @next_sid,
        @now,
		@user_name,
		@requestor,
		@op_name,
		NULL,
		NULL
	 )
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
END;

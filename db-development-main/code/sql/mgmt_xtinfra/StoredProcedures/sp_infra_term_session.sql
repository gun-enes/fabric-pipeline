
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_session_term]
	@session_id	[nvarchar](32)

/*
	Project  : SimpliFi
	Author   : extern.nagy_gellert@allianz.com
	Description : Terminate (kill) blocking session with logging
*/

AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @msg [nvarchar](99);
	DECLARE @now [datetime2];
	DECLARE @proc_name varchar(100) = 'sp_infra_session_term';
	DECLARE @log_detail_group uniqueidentifier = NEWID();

	BEGIN TRY

		-- Time of run
		SET @now = GETDATE();

		-- Remove spaces from parameter, convert UPPERCASE
		SET @session_id = UPPER(REPLACE(@session_id,' ',''));

		-- Validate parameter and log it
		EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'session_id', @session_id;

		IF @session_id is NULL OR @session_id = ''
		BEGIN
			SET @msg = 'Warning! The session_id to be terminated must be specified.';
			THROW 51002, @msg, 1;
		END;

		-- Throw error in case of wrong session_id
		IF (
			SELECT count(1)
			FROM [sys].[dm_pdw_lock_waits]
			WHERE 1 = 1
				AND [state] = 'Granted'
				AND [session_id] = @session_id
			) = 0
		BEGIN
			SET @msg = 'Warning! The session_id: ''' + @session_id + ''' is not a blocking process. Please re-check blocking sessions.';
			THROW 51003, @msg, 1;
		END;

		-- Log session info
		INSERT INTO [mgmt_xtinfra].[infra_session_term_master]
		-- Select blocking session details
		SELECT
			@now,
			SUSER_SNAME(),
			SESSION_ID(),
			@@SPID,
			[lw].[session_id],
			[es].[sql_spid],
			[lw].[wait_id],
			[lw].[type],
			[lw].[object_type],
			[lw].[object_name],
			[lw].[state] [wait_state],
			[es].[status] [session_status],
			[er].[status] [request_status],
			[es].[client_id],
			[es].[login_name],
			[es].[app_name],
			[er].[command],
			[es].[login_time],
			[lw].[request_time]
		FROM [sys].[dm_pdw_lock_waits] [lw]
		INNER JOIN [sys].[dm_pdw_exec_sessions] [es]
			ON [lw].[session_id] = [es].[session_id]
		LEFT OUTER JOIN [sys].[dm_pdw_exec_requests] [er]
			ON [lw].[request_id] = [er].[request_id]
		WHERE 1 = 1
			AND [lw].[state] = 'Granted'
			AND [lw].[session_id] = @session_id

		-- Kill session
		SET @msg = 'KILL ''' + @session_id + ''';'
		EXEC (@msg)

		EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'success';
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
	END CATCH;
END;


CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_lock_eval]

/*
	Project  : SimpliFi
	Author   : extern.nagy_gellert@allianz.com
	Description : Evaluate locking situation in the database
*/

AS
BEGIN

	SET NOCOUNT ON;

	-- Select locking info
	IF (
		SELECT count(1)
		FROM [sys].[dm_pdw_lock_waits] [lw]
		INNER JOIN [sys].[dm_pdw_exec_sessions] [es]
			ON [lw].[session_id] = [es].[session_id]
		WHERE 1 = 1
			AND [lw].[state] = 'Granted'
			AND [es].[sql_spid] != @@SPID
		) = 0
	BEGIN
		SELECT
		[BLOCKING sessions] = 'No blocking processes found.'
	END
	ELSE
	BEGIN
		SELECT
			[BLOCKING sessions] =
			CASE
				WHEN [lw].[wait_id] = 0 THEN [lw].[session_id]
				ELSE ''
			END,
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
			AND [es].[sql_spid] != @@SPID
		ORDER BY [lw].[session_id] asc, [lw].[wait_id] asc;
	END;

	IF (
		SELECT count(1)
		FROM [sys].[dm_pdw_lock_waits]
			WHERE [state] != 'Granted'
	) = 0
	BEGIN
		SELECT
		[VICTIM sessions] = 'No waiting processes found.'
	END
	ELSE
	BEGIN
		SELECT
			[lw].[session_id] [VICTIM sessions],
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
			AND [lw].[state] != 'Granted'
		ORDER BY [lw].[session_id] asc, [lw].[wait_id] asc;
	END;

END;

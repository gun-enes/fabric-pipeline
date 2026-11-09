CREATE PROC [mgmt_xtinfra].[sp_infra_sess_stat]
	/* Scope     : Procedure will help to get the session details/session wait
 * Project   : ADP Simplfi
 * Acitivity : Dedicated SQL pool deployment
 * Author    : jyothish.b@allianz.com
 */
	(
	@sess_p1 [varchar](25),
	@sess_p2 [varchar](25),
	@sess_p3 [varchar](25)
)
AS
BEGIN
	DECLARE @cmd varchar(4000)
	DECLARE @db_name varchar(1000)
	DECLARE @current_user varchar(1000)
	DECLARE @now DateTime =(
	select
		SYSDATETIME())
	DECLARE @output varchar(1000) = 'TEST'
	SET @db_name = db_name();
	SET @current_user = current_user;
	IF @sess_p1 NOT IN ('TOP10', 'SESS_WAIT')
BEGIN
		;THROW 555550,
'Invalid value for @sess_p1 parameter. Expected values  TOP10 or SESS_WAIT',
1;
	END
	IF (upper(@sess_p1) IN ('TOP10')
		and upper(@sess_p2) in ('LONG')
		and upper(@sess_p3) in ('LIVE'))
BEGIN
		SELECT
			top 10
			ROW_NUMBER() OVER(
	ORDER BY r.[submit_time] ASC) AS rowid
     ,
			r.[session_id]
	,
			r.[request_id]
	,
			r.[status]
	,
			s.[login_name]
	,
			r.[command]
	,
			r.[submit_time]
	,
			r.[end_time]
	,
			datediff(ms, r.[submit_time], r.[end_compile_time]) AS [compile_time_ms]
	,
			datediff(ms, r.[end_compile_time], r.[start_time]) AS [wait_time_ms]
	,
			datediff(ms, r.[start_time], r.[end_time]) AS [execution_time_ms]
	,
			r.[total_elapsed_time] AS [total_time_ms]
	,
			sum(CASE WHEN row_count =('-1') THEN 0 ELSE row_count END) AS [Total_Rows_Processed]
	,
			r.[label]
	,
			r.[resource_allocation_percentage]
	,
			r.[importance]
	,
			r.[group_name]
	,
			r.[classifier_name]
	,
			r.[result_cache_hit]
	,
			s.[app_name]
		FROM
			sys.dm_pdw_exec_requests r
			LEFT JOIN sys.dm_pdw_exec_sessions s
			ON
	r.[session_id] = s.[session_id]
			LEFT JOIN sys.dm_pdw_request_steps steps
			ON
	r.[request_id] = steps.[request_id]
		WHERE
	s.[session_id] <> session_id()
			and r.[status] = 'Running'
		GROUP BY
	r.[request_id],
	r.[session_id],
	r.[status],
	r.[submit_time],
	r.[end_compile_time],
	r.[start_time],
	r.[end_time],
	r.[total_elapsed_time],
	r.[label],
	r.[command],
	r.[importance],
	r.[group_name],
	r.[classifier_name],
	r.[resource_allocation_percentage],
	r.[result_cache_hit],
	s.[login_name],
	s.[app_name]
	END
ELSE IF(upper(@sess_p1) IN ('SESS_WAIT')
		and upper(@sess_p2) in ('SID')
		and @sess_p3 is not NULL)
BEGIN
		SELECT
			w.[wait_id]
,
			w.[session_id]
,
			w.[type] AS Wait_type
,
			w.[object_type]
,
			w.[object_name]
,
			w.[request_id]
,
			w.[request_time]
,
			w.[acquire_time]
,
			w.[state]
,
			w.[priority]
,
			SESSION_ID() AS Current_session
,
			s.[status] AS Session_status
,
			s.[login_name]
,
			s.[query_count]
,
			s.[client_id]
,
			s.[sql_spid]
,
			r.[command] AS Request_command
,
			r.[label]
,
			r.[status] AS Request_status
,
			r.[submit_time]
,
			r.[start_time]
,
			r.[end_compile_time]
,
			r.[end_time]
,
			DATEDIFF(ms, r.[submit_time], r.[start_time]) AS Request_queue_time_ms
,
			DATEDIFF(ms, r.[start_time], r.[end_compile_time]) AS Request_compile_time_ms
,
			DATEDIFF(ms, r.[end_compile_time], r.[end_time]) AS Request_execution_time_ms
,
			r.[total_elapsed_time]
		FROM
			sys.dm_pdw_waits w
			JOIN sys.dm_pdw_exec_sessions s ON
	w.[session_id] = s.[session_id]
			JOIN sys.dm_pdw_exec_requests r ON
	w.[request_id] = r.[request_id]
		WHERE
	w.[session_id] <> SESSION_ID()
			and w.[session_id] = @sess_p3
	END
ELSE IF(upper(@sess_p1) IN ('TOP10')
		and upper(@sess_p2) in ('DMS')
		and upper(@sess_p3) in ('MOVE'))
BEGIN
		WITH
			step_data
			AS
			(
				SELECT
					SUM(rows_processed) AS Step_Rows_Processed
		,
					SUM(bytes_processed) AS Step_Bytes_Processed
		,
					request_id
		,
					step_index
		,
					status
		,
					type
				FROM
					sys.dm_pdw_dms_workers
				--WHERE status != 'StepComplete'
				Group by
		  request_id
		,
	step_index
		,
	status
		,
	type
			)
		SELECT
			top 10
			ROW_NUMBER() OVER(
	ORDER BY step_data.[Step_rows_processed] desc) AS rowid
	,
			step_data.request_id
	,
			per.session_id
	,
			step_data.Step_rows_processed
	,
			step_data.step_bytes_processed
	,
			(step_data.Step_Bytes_Processed / 1024 / 1024 / 1024) AS Step_GB_Processed
	,
			step_data.step_index
	,
			step_data.type
	,
			step_data.status as Step_status
	,
			per.status AS QID_Status
	,
			per.total_elapsed_time / 1000 / 60 as 'QID_Elapsed_Time (min)'
	,
			per.command AS 'QID_Command'
	,
			per.resource_class
	,
			per.importance
		FROM
			step_data
			LEFT JOIN sys.dm_pdw_exec_requests per
			ON
	step_data.request_id = per.request_id
	-- WHERE per.status = 'Running'
	-- ORDER BY step_data.Step_rows_processed DESC
	END
ELSE IF(upper(@sess_p1) IN ('TOP10')
		and upper(@sess_p2) in ('TEMP')
		and upper(@sess_p3) in ('LIVE'))
BEGIN
		SELECT
			top 10
			ROW_NUMBER() OVER(
	ORDER BY sum(pdw.bytes_processed) desc) AS rowid
	,
			req.request_id
	,
			sum(pdw.bytes_processed) as 'bytes_written'
	,
			CAST(sum(pdw.bytes_processed)/ 1024.0 / 1024.0 / 1024.0 AS Decimal(10,
	1)) AS 'GB_written'
	,
			sum(pdw.rows_processed) as 'rows_written'
	,
			'EXEC sp_requests_detail @request_id=''' + req.request_id + '''' AS 'request_detail_command'
		from
			[sys].[dm_pdw_dms_workers] pdw
			JOIN sys.dm_pdw_exec_requests req
			ON
	pdw.request_id = req.request_id
		WHERE
	pdw.type = 'Writer'
		--AND req.status = 'running'
		GROUP BY
	req.request_id
	--ORDER BY bytes_written desc
	END
END

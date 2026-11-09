
CREATE PROCEDURE [mgmt_xtinfra].[sp_permission_audit]
	@type [varchar](9)

/*
	Project  : SimpliFi
	Author   : extern.nagy_gellert@allianz.com
	Description : Document all permissions set on the database at regular intervals, remove old records past retention time
*/

AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @msg [varchar](99);
	DECLARE @now [datetime2];
	DECLARE @proc_name varchar(100) = 'sp_permission_audit';
	DECLARE @log_detail_group uniqueidentifier = NEWID();

	BEGIN TRY
	--- add log entry for our job
	EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
	EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'type', @type

	-- Remove spaces from parameter, convert UPPERCASE
	SET @type = UPPER(REPLACE(@type,' ',''));
	-- Time of run
	SET @now = GETDATE();

	-- Default run type is Manual when empty
	IF @type is NULL OR @type = ''
	BEGIN
		SET @type = 'MANUAL';
	END;

	-- Throw error in case of wrong parameter
	IF @type NOT in ('MANUAL', 'DAILY', 'WEEKLY', 'MONTHLY')
	BEGIN
		SET @msg = 'Unknown @type parameter: ''' + @type + '''. Should be : MANUAL, DAILY, WEEKLY, MONTHLY ';
		THROW 51001, @msg, 1;
	END;

		-- Insert result into table
		INSERT INTO [mgmt_xtinfra].[permission_audit]

		-- Select Database-level permissions
		SELECT
			@type as [type],
			@now as [date],
			[dbper].[state_desc] as [Perm1],
			[dbper].[permission_name] as [Perm2],
			[dbper].[class_desc] as [Level1],
			db_name() as [Level2],
			[dbpri].[name] as [Grantee]
		FROM [sys].[database_permissions] as [dbper]
		INNER JOIN [sys].[database_principals] as [dbpri]
			ON [dbper].[grantee_principal_id] = [dbpri].[principal_id]
		WHERE [dbper].[class_desc] = 'DATABASE'

		UNION ALL

		-- Select Schema-level permissions
		SELECT
			@type as [type],
			@now as [date],
			[dbper].[state_desc] as [Perm1],
			[dbper].[permission_name] as [Perm2],
			[dbper].[class_desc] as [Level1],
			[sch].[name] as [Level2],
			[dbpri].[name] as [Grantee]
		FROM [sys].[database_permissions] as [dbper]
		INNER JOIN [sys].[database_principals] as [dbpri]
			ON [dbper].[grantee_principal_id] = [dbpri].[principal_id]
		INNER JOIN [sys].[schemas] as [sch]
			ON [dbper].[major_id] = [sch].[schema_id]
		WHERE [dbper].[class_desc] = 'SCHEMA'

		UNION ALL

		-- Select Object-level permissions
		SELECT
			@type as [type],
			@now as [date],
			[dbper].[state_desc] as [Perm1],
			[dbper].[permission_name] as [Perm2],
			[dbper].[class_desc] as [Level1],
			[sch].[name] + '.' + [obj].[name] as [Level2],
			[dbpri].[name] as [Grantee]
		FROM [sys].[database_permissions] as [dbper]
		INNER JOIN [sys].[database_principals] as [dbpri]
			ON [dbper].[grantee_principal_id] = [dbpri].[principal_id]
		INNER JOIN [sys].[objects] as [obj]
			ON [dbper].[major_id] = [obj].[object_id]
		INNER JOIN [sys].[schemas] as [sch]
			ON [obj].[schema_id] = [sch].[schema_id]
		WHERE [dbper].[class_desc] = 'OBJECT_OR_COLUMN'


		-- Retention for Daily type, 30 days
		DELETE FROM [mgmt_xtinfra].[permission_audit]
		WHERE 1 = 1
			AND [type] = 'DAILY'
			AND DATEDIFF(day, [date], @now) > 30

		-- Retention for Weekly type, 8 weeks
		DELETE FROM [mgmt_xtinfra].[permission_audit]
		WHERE 1 = 1
			AND [type] = 'WEEKLY'
			AND DATEDIFF(week, [date], @now) > 8

		-- Retention for Monthly type, 6 months
		DELETE FROM [mgmt_xtinfra].[permission_audit]
		WHERE 1 = 1
			AND [type] = 'MONTHLY'
			AND DATEDIFF(month, [date], @now) > 6

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

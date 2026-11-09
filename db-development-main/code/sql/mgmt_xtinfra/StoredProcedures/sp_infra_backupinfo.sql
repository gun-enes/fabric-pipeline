CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_backupinfo]
	@days [int]
/*
	Project  : SimpliFi
	Author   : extern.nagy_gellert@allianz.com
	Description : List recent DB backup information, default 7 days
*/
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @msg [varchar](99);
	DECLARE @now [datetime2];
	-- Time of run
	SET @now = GETDATE();
	-- Default 7 days
	IF @days is NULL OR @days = 0
	BEGIN
		SET @days = 7;
	END;
	-- Throw error in case value out of bounds
	IF @days < 0 OR @days > 99
	BEGIN
		SET @msg = '@days parameter should be integer value between 1 and 99 ';
		THROW 51001, @msg, 1;
	END;
	-- Select backup info
  SELECT
       [name]
      ,[start_time]
      ,[end_time]
      ,[operation_type]
      ,[mode]
      ,[database_name]
      ,[status]
      ,[progress]
  FROM [sys].[pdw_loader_backup_runs]
	WHERE 1 = 1
	AND DATEDIFF(day, [start_time], @now) <= @days
  ORDER BY [start_time] desc
END;

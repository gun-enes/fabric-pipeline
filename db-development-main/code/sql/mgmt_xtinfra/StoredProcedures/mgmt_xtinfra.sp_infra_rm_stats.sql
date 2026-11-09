CREATE PROCEDURE mgmt_xtinfra.sp_infra_rm_stat
/* Scope     : This procedure is for removing stats
 * Project   : Simplfi
 * Acitivity : Dedicated SQL pool deployment
 * Author    : jyothish.b@allianz.com
 */
(
@stats_rm_type varchar(1000)
-- OPTIONS: SCHEMA,ALL
,
@schema_name varchar(100),
-- OPTIONS: schema_name
  @workSpace nvarchar(120) ,
  @appName as nvarchar(100)
)
AS
BEGIN
	DECLARE @cmd varchar(4000)
    DECLARE @i INT
    DECLARE @t INT
    DECLARE @s NVARCHAR(4000) = N''
  DECLARE @session_id_counter int = (
	SELECT
		ISNULL(MAX(session_id),
		0)
	FROM
		mgmt_xtinfra.infra_stats_master) + 1
  DECLARE @exec_id_counter int = (
	SELECT
		ISNULL(MAX(execid),
		0) AS maxexecid
	FROM
		mgmt_xtinfra.infra_stats_master) + 1
  DECLARE @db_name varchar(1000)
  DECLARE @current_user varchar(1000)
  DECLARE @now DateTime =(
	select
		SYSDATETIME())
  DECLARE @output varchar(1000) = 'TEST'
  DECLARE @job_desc varchar(1000) = 'Infra stats master operation'
  DECLARE @scriptversionid varchar(1000) = (
	SELECT
		scriptversionid
	FROM
		mgmt_xtinfra.infra_script_master
	where
		script_status = 'current')

SET
	@db_name = db_name();

SET
@current_user = current_user;

-- checking parameters stats_rm_type for the procedure

IF upper(@stats_rm_type) NOT IN ('ALL','SCHEMA')
BEGIN
	;THROW 555550,
'Invalid value for stats_rm_type parameter. Expected values  ALL OR SCHEMA, retry procedure with corect expected values',
1
END

IF (upper(@stats_rm_type) IN ('SCHEMA'))
BEGIN
	SET
	@job_desc = 'STATS_Removal job for schema' + @schema_name
END
ELSE IF (UPPER(@stats_rm_type) IN ('ALL'))
BEGIN
	SET
	@job_desc = 'User created STATS_Removal for all schema'
END
ELSE
BEGIN
print 'Wrong job description'
END

IF (upper(@stats_rm_type) IN ('SCHEMA') and (@schema_name) is null)
BEGIN
	;THROW 555550,
'Invalid value for stats_rm_type parameter. Expecting schema name, retry procedure with corect expected values',
1;
END
-- Stats removal for a specific schema starting here
ELSE IF (upper(@stats_rm_type) IN ('SCHEMA') and (@schema_name) is not null)
BEGIN
 IF OBJECT_ID('tempdb..#drop_schema_stats_ddl') IS NOT NULL
   BEGIN

		DROP TABLE #drop_schema_stats_ddl;
   END
ELSE
BEGIN
INSERT
	INTO
	mgmt_xtinfra.infra_stats_master (execid ,
	session_id,
	scriptversionid ,
	dbname ,
	job_desc ,
	status ,
	job_start_time,
	job_end_time,
	exec_user,
    workspace_name,
    app_name )
    SELECT
	@exec_id_counter,
	@session_id_counter,
	@scriptversionid,
	@db_name,
	@job_desc,
	'started',
	@now,
	@now,
	@current_user,
    @workSpace,
    @appName

CREATE TABLE #drop_schema_stats_ddl
WITH ( DISTRIBUTION = HASH([DDL_STATS_DROP])
,
LOCATION = USER_DB
)
AS
WITH JYO
AS
(
SELECT
'DROP STATISTICS [' + sm.name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + '].[' + tb.name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + '].[' + st.name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + '];' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 as DDL_STATS_DROP,
ROW_NUMBER()
OVER(
ORDER BY
(
SELECT
NULL)) AS [seq_nmbr]
FROM
sys.objects AS ob
JOIN sys.stats AS st ON
ob.[object_id] = st.[object_id]
JOIN sys.stats_columns AS sc ON
st.[stats_id] = sc.[stats_id]
AND st.[object_id] = sc.[object_id]
JOIN sys.columns AS co ON
sc.[column_id] = co.[column_id]
AND sc.[object_id] = co.[object_id]
JOIN sys.types AS ty ON
co.[user_type_id] = ty.[user_type_id]
JOIN sys.tables AS tb ON
co.[object_id] = tb.[object_id]
JOIN sys.schemas AS sm ON
tb.[schema_id] = sm.[schema_id]
WHERE
1 = 1
AND st.[user_created] = 1 and sm.name = @schema_name)
select [DDL_STATS_DROP] ,[seq_nmbr] from JYO

SET @i  = 1
SET @t  = (
SELECT
COUNT (*) FROM
#drop_schema_stats_ddl)
SET @s = N''

WHILE @i <= @t
BEGIN
SET
@s =(
SELECT
DDL_STATS_DROP
FROM
#drop_schema_stats_ddl
WHERE
seq_nmbr = @i);

PRINT @s
EXEC sp_executesql @s
SET
@i += 1
END;

DROP TABLE #drop_schema_stats_ddl;
INSERT
	INTO
	mgmt_xtinfra.infra_stats_master (execid ,
	session_id,
	scriptversionid ,
	dbname ,
	job_desc ,
	status ,
	job_start_time,
	job_end_time,
	exec_user,
    workspace_name,
    app_name )
    SELECT
	@exec_id_counter,
	@session_id_counter,
	@scriptversionid,
	@db_name,
	@job_desc,
	'completed',
	@now,
	@now,
	@current_user,
    @workSpace,
    @appName
END
END

--- below steps drop all the user created statistics from all the schemas

IF (upper(@stats_rm_type)  IN ('ALL') and (@schema_name) is not null)
BEGIN
	;THROW 555550,
'Invalid value for @stats_rm_type parameter. Expected values  for schema name is null for ALL schemas',
1;
END
---
ELSE IF (upper(@stats_rm_type)  IN ('ALL') and (@schema_name) is null)
BEGIN       ---else if begin starting here
   IF OBJECT_ID('tempdb..#drop_all_stats_ddl') IS NOT NULL
    BEGIN

		DROP TABLE #drop_all_stats_ddl;
    END
    ELSE  -- else begin starting here
	BEGIN
INSERT
	INTO
	mgmt_xtinfra.infra_stats_master (execid ,
	session_id,
	scriptversionid ,
	dbname ,
	job_desc ,
	status ,
	job_start_time,
	job_end_time,
	exec_user,
    workspace_name,
    app_name )
    SELECT
	@exec_id_counter,
	@session_id_counter,
	@scriptversionid,
	@db_name,
	@job_desc,
	'started',
	@now,
	@now,
	@current_user,
    @workSpace,
    @appName

CREATE TABLE #drop_all_stats_ddl
WITH ( DISTRIBUTION = HASH([DDL_STATS_DROP])
,
LOCATION = USER_DB
)
AS
WITH JYO
AS
(
SELECT
'DROP STATISTICS [' + sm.name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + '].[' + tb.name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + '].[' + st.name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + '];' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 as DDL_STATS_DROP,
ROW_NUMBER()
OVER(
ORDER BY
(
SELECT
NULL)) AS [seq_nmbr]
FROM
sys.objects AS ob
JOIN sys.stats AS st ON
ob.[object_id] = st.[object_id]
JOIN sys.stats_columns AS sc ON
st.[stats_id] = sc.[stats_id]
AND st.[object_id] = sc.[object_id]
JOIN sys.columns AS co ON
sc.[column_id] = co.[column_id]
AND sc.[object_id] = co.[object_id]
JOIN sys.types AS ty ON
co.[user_type_id] = ty.[user_type_id]
JOIN sys.tables AS tb ON
co.[object_id] = tb.[object_id]
JOIN sys.schemas AS sm ON
tb.[schema_id] = sm.[schema_id]
WHERE
1 = 1
AND st.[user_created] = 1)
select [DDL_STATS_DROP] ,[seq_nmbr] from JYO

SET @i  = 1
SET @t  = (
SELECT
COUNT (*) FROM
#drop_all_stats_ddl)
SET @s  = N''
;

WHILE @i <= @t
BEGIN
SET
@s =(
SELECT
DDL_STATS_DROP
FROM
#drop_all_stats_ddl
WHERE
seq_nmbr = @i);

PRINT @s
EXEC sp_executesql @s
SET
@i += 1
END

DROP TABLE #drop_all_stats_ddl;

INSERT
	INTO
	mgmt_xtinfra.infra_stats_master (execid ,
	session_id,
	scriptversionid ,
	dbname ,
	job_desc ,
	status ,
	job_start_time,
	job_end_time,
	exec_user,
    workspace_name,
    app_name )
    SELECT
	@exec_id_counter,
	@session_id_counter,
	@scriptversionid,
	@db_name,
	@job_desc,
	'completed',
	@now,
	@now,
	@current_user,
    @workSpace,
    @appName
END
END
END

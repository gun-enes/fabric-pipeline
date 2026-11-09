-- This file contains SQL statements that will be executed before the build script.
-- Object Statistical removal for mgmt_xtinfra schema
-- Author : Jyothish.b@allianz.com
-- Static procedure for future stats removel mgmt_xtinfra.sp_infra_rm_stats
DECLARE @i INT
DECLARE @t INT
DECLARE @s NVARCHAR(4000) = N''
BEGIN
   PRINT('Removal of stats on mgmt_xtinfra schema and this step is common for both ADP and SPF');
   BEGIN try
      IF EXISTS(SELECT 1 FROM sys.schemas
          WHERE Name = N'mgmt_xtinfra'
          )
      BEGIN
        IF OBJECT_ID('tempdb..#drop_schema_stats_ddl') IS NOT NULL
        BEGIN
		DROP TABLE #drop_schema_stats_ddl;
        END
   ELSE
      BEGIN
        CREATE TABLE #drop_schema_stats_ddl WITH ( DISTRIBUTION = HASH([DDL_STATS_DROP])
         ,LOCATION = USER_DB)
         AS
         WITH STAT_VIEW
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
         AND st.[user_created] = 1 and sm.name = 'mgmt_xtinfra')
         select [DDL_STATS_DROP] ,[seq_nmbr] from STAT_VIEW

         SET @i  = 1
         SET @t  = (
         SELECT
         COUNT (*) FROM
         #drop_schema_stats_ddl)
         SET @s  = N''
         ;

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
         END
         PRINT('Removal of stats on mgmt_xtinfra schema has been completed')
      END
   END
   END try
   BEGIN catch
      print('Schema [mgmt_xtinfra] is not available,hence ignore dropping statistics');
   END catch
   --Removing all the temp tables which have been used during the execution
   print('Removing all the temp tables which have been used during the execution');
   IF OBJECT_ID ('tempdb..#drop_schema_stats_ddl') IS  NOT NULL
   DROP TABLE #drop_schema_stats_ddl;
END

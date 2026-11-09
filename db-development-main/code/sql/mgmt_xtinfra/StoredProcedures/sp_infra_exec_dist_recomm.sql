CREATE PROCEDURE mgmt_xtinfra.sp_infra_exec_dist_recomm
	@NumMaxQueries int,
	@Queries NVARCHAR(MAX)
AS
/* Scope    : Analyze the long running queries and recommend best distribution method
 * Project  : Simplfi
 * Activity : Dedicated SQL pool deployment
 * Author   : jyothish.b@allianz.com
 */
   BEGIN
	DECLARE @sql nvarchar(MAX);
	DECLARE @sessionid nvarchar(max) = SESSION_ID();
	DECLARE @guid nvarchar(100) = REPLACE(NEWID(), '-', '');
	DECLARE @guidpusher nvarchar(max) = CONCAT(N'    --distrib_advisor_correlation_id_', @guid, CHAR(13), CHAR(10));
	DECLARE @recostring nvarchar(max);

	-- Write Distribution starting here
	IF (@Queries is NULL)
		BEGIN
			if (@NumMaxQueries is NULL or @NumMaxQueries < 1 or @NumMaxQueries > 100)
				BEGIN
					RAISERROR(N'Max queries value must be in [1...100] range, changing to 100.', 0, -1);
					SET @NumMaxQueries = 100;
				END
			SET @sql = 'with topnqueries as
					(select top(@nmq) command, MIN(total_elapsed_time) AS min_te, AVG(total_elapsed_time) AS avg_te, COUNT(*) AS num_runs, SUM(total_elapsed_time) AS tot_te
					from (select command = case when command2 is null then command else command2 end, total_elapsed_time
					from sys.dm_pdw_exec_requests
					where
						command not like ''%USE [[]DWShellDb%\'' and
						command not like ''%DistributionAdvisor%'' and
						command not like ''--Backing up Logical Azure Database%\'' and
						command not like ''%select % as ConnectionProtocol%'' and
						command like ''%select%'' and
						command not like ''%set recommendations%'' and
						command not like ''USE [[]%]'' and
						command not like ''%sys.system_sql_modules%'' and
						command not like ''%insert%'' and
						command not like ''%sys.indexes%'' and
						command not like ''%merge%'' and
						command not like ''%CREATE%TABLE%'' and
						command not like ''%dm_pdw_exec_requests%'' and
						command not like ''%sys.databases%'' and
						command not like ''%trancount%'' and
						command not like ''%spid%'' and total_elapsed_time > 300 and
						command not like ''%SERVERPROPERTY%'' and resource_class != ''NULL'' and
						command not like ''%sys.objects%'' and
						command not like ''%sys.tables%'' and
						command not like ''%sys.schemas%'' and
						command not like ''%sys.dm_pdw_%'' and
						command not like ''%CREATE STATISTICS%'' and
						command not like ''%UPDATE STATISTICS%'' and
						status = ''Completed'') x
					GROUP BY command
					ORDER BY tot_te desc),
				allqueries as (select command, tot_te from topnqueries union all select * from mgmt_xtinfra.DistributionAdvisorSelectedQueries),
				allqueriesgrouped as (select command, sum(tot_te) as tot_te from allqueries group by command),
				topnqueriesranked as (select REPLACE(command, '''''';'''''', ''CHAR(59)'') as command, tot_te, row_number() over (order by tot_te desc) as rn from allqueriesgrouped)
			select @recostring =
			''set recommendations on;'' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
			+ ''/****************** Actual queries follow ****************************/'' + CHAR(13) + CHAR(10) +
			STRING_AGG(
				''/************************** Query q'' + cast (rn-1 as nvarchar(max)) + '' ********************************/'' + CHAR(13) + CHAR(10) +
				(case
				when charindex('';'', command) > 0
				then REPLACE(REPLACE(cast(command AS nvarchar(max)), ''--distrib_advisor_correlation_id_'', ''--''), '';'', @guidpusher)
				else concat(command, @guidpusher)
				end),
				'';'' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)) +
			 + CHAR(13) + CHAR(10) + ''/******************** End actual queries **************************/'' + CHAR(13) + CHAR(10) +
			''set recommendations off;''
			from topnqueriesranked';
--		    print (@sql);
			END
	ELSE
		BEGIN
			SET @NumMaxQueries = 100;
			SET @Queries = REPLACE(@Queries, ''';''', 'char(59)');
			SET @sql = 'with userqueries as
						(select CONCAT(value,'';'') as command, ordinal as tot_te
						from STRING_SPLIT(@customQueries, '';'', 1) where trim(value) <> '''' union all select * from mgmt_xtinfra.DistributionAdvisorSelectedQueries),
						topnqueriesranked as (select *, row_number() over (order by tot_te desc) as rn from userqueries)
						select @recostring =
						''set recommendations on;'' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
						+ ''/****************** Actual queries follow ****************************/'' + CHAR(13) + CHAR(10) +
						STRING_AGG(
							''/************************** Query q'' + cast (rn-1 as nvarchar(max)) + '' ********************************/'' + CHAR(13) + CHAR(10) +
							(case
							when charindex('';'', command) > 0
							then REPLACE(REPLACE(cast(command AS nvarchar(max)), ''--distrib_advisor_correlation_id_'', ''--''), '';'', @guidpusher)
							else concat(command, @guidpusher)
							end),
							'';'' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)) +
						 + CHAR(13) + CHAR(10) + ''/******************** End actual queries **************************/'' + CHAR(13) + CHAR(10) +
						''set recommendations off;''
						from topnqueriesranked';
--					print (@sql);
			END


	EXEC sp_executesql @sql, N'@recostring nvarchar(max) OUTPUT, @guidpusher nvarchar(max), @nmq int, @customQueries nvarchar(max)', @recostring OUTPUT, @guidpusher, @NumMaxQueries, @Queries;


	/*
			-- For debugging purposes.
			SELECT @recostring AS Command_To_Invoke_Distribution_Advisor;

			-- A command to invoke Distribution Advisor with the above string.
			EXEC sp_executesql @recostring;

			RAISERROR(N'Please use ''sp_infra_read_dist_recomm'' stored procedure after recommendation is created to retrieve it', 0, -1);
	*/
-- Read recommendation section starting here

	-- get the answer from ring buffer; we may have to wait a bit, so we do a few tries for the ring buffer to get ready
	DECLARE @recommendation nvarchar(max);

    SET @sessionid = ( select max(session_id) from sys.dm_pdw_distrib_advisor_results where session_id not in (select advisor_sid from mgmt_xtinfra.infra_dist_master))
	DECLARE @readrecommendation nvarchar(max) = (select recommendation from sys.dm_pdw_distrib_advisor_results where session_id=@sessionid)

	DECLARE @DelayStart datetime = GETDATE();
   --  print (@sessionid)
     SET @recommendation = (select recommendation from sys.dm_pdw_distrib_advisor_results where @sessionid = session_id);
 --  print @readrecommendation
 --  print ('----------------------')
 --  print @recommendation

	-- Retrying for 10 seconds
	WHILE (@recommendation is null or len(@recommendation) = 0) and  DATEDIFF(second, @DelayStart, GETDATE()) < 10
	BEGIN
		EXEC sp_executesql @readrecommendation, N'@recommendation nvarchar(max) OUTPUT, @sessionid nvarchar(max)', @recommendation OUTPUT, @sessionid;
--	    insert into mgmt_xtinfra.jyo_log values (@sessionid);
--	    insert into mgmt_xtinfra.jyo_log values ('I am here recomm null');
	END
--	 print ('----------------------')
--     print @recommendation
	-- parsing and formatting the recommendation
--	EXEC mgmt_xtinfra.sp_infra_format_recomm @recommendation;
	BEGIN
    IF (@recommendation IS NULL OR len(@recommendation) = 0)
      BEGIN
          print ('No recommendation identified now');
      END
    ELSE
    BEGIN
        -- Parse the recommendation result
        DECLARE @FirstDistribBegin INT = PATINDEX('%Table Distribution Changes%', @recommendation);
        DECLARE @FirstDistribEnd INT = PATINDEX('%------------------------------------------------------------%', @recommendation);
        DECLARE @JumpPast NVARCHAR(max) = 'Table Distribution Changes';

		SET @FirstDistribBegin = @FirstDistribBegin + LEN(@JumpPast) + 2; -- +1 to eat newline at the beginning
		DECLARE @DistribLength int = @FirstDistribEnd - @FirstDistribBegin - 2; -- extra -2 to remove newlines at the end

		DECLARE @exec_id_counter int = (
	    SELECT
		ISNULL(MAX(execid),
		0) AS maxexecid
	         FROM
		mgmt_xtinfra.infra_dist_master) + 1
        DECLARE @db_name varchar(1000)
        DECLARE @current_user varchar(1000)
        DECLARE @now DateTime =(
        select
        	SYSDATETIME())
        DECLARE @output varchar(1000) = 'TEST'
        DECLARE @job_desc varchar(1000) = 'Infra distribution master operation'
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

        IF (@DistribLength <= 0)
          BEGIN
              RAISERROR (N'No distribution to show. The query does not involve any tables, or the tables do not exist.', 18, - 1);
          END
        ELSE
            DECLARE @FirstDistrib NVARCHAR(max);

        SELECT @FirstDistrib = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(SUBSTRING(@recommendation, @FirstDistribBegin, @DistribLength), CHAR(9), ''), CHAR(13), ''), '->', ''), '  ', ' '), ' ', '","'), CHAR(10), '"],["');

        SELECT @FirstDistrib = REPLACE(REPLACE(@FirstDistrib, 'Distributed', 'Hash'), ':', '');

        SELECT @FirstDistrib = '[["' + @FirstDistrib + '"]]';


INSERT
	INTO
	mgmt_xtinfra.infra_dist_master (execid ,
	scriptversionid ,
	dbname,
	job_desc,
	job_time,
	exec_user,
	TableName,
	CurrentDistribution,
	SuggestedDistribution,
    advisor_sid,
	CMD,
	Remarks)
  SELECT
  	@exec_id_counter,@scriptversionid,@db_name,@job_desc,@now,@current_user,y.TableName
            , CurrentDistribution
            , SuggestedDistribution
            ,@sessionid
            , ChangeCommand = CASE
                WHEN CurrentDistribution = SuggestedDistribution
                    THEN N'<no change>'
                ELSE CONCAT (
                        N'CREATE TABLE ', y.TableName, N'_changed
                        WITH (DISTRIBUTION=', REPLACE(REPLACE(SuggestedDistribution, 'replicated', 'REPLICATE'), 'Hash', 'HASH'), N', ', i.TableIndex, ')
                        AS SELECT * FROM ', y.TableName, N';
                        DROP TABLE ', y.TableName, ';
                        RENAME OBJECT ', y.TableName, N'_changed TO ', i.tableName, ';')
                END
            , Remarks = CASE
                WHEN PATINDEX('%Hash%', CurrentDistribution) > 0
                    AND CHARINDEX(',', CurrentDistribution) > 0
                    THEN N'MCD tables are not considered by the current DA version.'
                ELSE ''
                END
        FROM (
            SELECT [0] AS TableName
                , [1] AS CurrentDistribution
                , [2] AS SuggestedDistribution
            FROM (
                SELECT pvt.*
                FROM (
                    SELECT row_no = [rows].[key]
                        , col_no = [cols].[key]
                        , cols.[value]
                    FROM (
                        SELECT [json] = @FirstDistrib
                        ) step1
                    CROSS APPLY openjson([json]) [rows]
                    CROSS APPLY openjson([rows].[value]) [cols]
                    ) base
                pivot(max(base.[value]) FOR base.col_no IN ([0], [1], [2])) pvt
                ) x
            WHERE [1] IS NOT NULL
                AND [2] IS NOT NULL
            ) y
        JOIN (
            SELECT CONCAT (
                    DB_NAME()
                    , '.'
                    , OBJECT_SCHEMA_NAME(t.object_id)
                    , '.'
                    , t.name
                    ) AS FullObjectName
                , OBJECT_SCHEMA_NAME(t.object_id) AS schemaName
                , t.name AS tableName
                , i.type
                , CASE i.type
                    WHEN 0
                        THEN 'HEAP'
                    WHEN 1
                        THEN CONCAT ('CLUSTERED INDEX (', STRING_AGG(CAST(c.name as VARCHAR(MAX)), ', ') WITHIN GROUP (ORDER BY ic.key_ordinal ASC), ')')
                    WHEN 5
                        THEN 'CLUSTERED COLUMNSTORE INDEX'
                    END AS TableIndex
            FROM sys.tables t
            LEFT JOIN sys.indexes i
                ON t.object_id = i.object_id
                    AND i.type IN (0, 1, 5)
            LEFT JOIN sys.index_columns ic
                ON i.index_id = ic.index_id
                    AND i.object_id = ic.object_id
            LEFT JOIN sys.columns c
                ON ic.column_id = c.column_id
                    AND ic.object_id = c.object_id
            GROUP BY t.name
                , t.object_id
                , i.name
                , i.type
            ) i
            ON y.TableName = i.FullObjectName;

delete from mgmt_xtinfra.infra_dist_master WHERE DATEDIFF(day, job_time, @now) > 60;

    END
END
END

BEGIN
    DECLARE @wrkspc_json_entities [nvarchar](MAX) = N'$(workspaces)';
    DECLARE @wrkspc_entities_counter int;
    DECLARE @wrkspc_entities_total int;
    DECLARE @wrkspc_sql_stmt [nvarchar](1024);

    -- perform sanitization of input
    -- this is required because sqlpackage doubles closing brackets
    SET @wrkspc_json_entities = REPLACE(@wrkspc_json_entities, ']]', ']');

    PRINT 'BEGIN: Running PostDeployment script for workspaces';
    PRINT 'input: ' + @wrkspc_json_entities;

    IF ISJSON(@wrkspc_json_entities) > 0
    BEGIN
        -- drop the temp table if it's still there
        IF OBJECT_ID ('tempdb..#TBL') IS NOT NULL
            DROP TABLE #TBL;

        -- create the TBL table with the format required by the WORKSPACE entity
        CREATE TABLE #TBL (
            sequence int,
            workspace_name nvarchar(10) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
        ) WITH ( DISTRIBUTION = ROUND_ROBIN );

        BEGIN TRY
            -- open json and read all values into the temp table
            -- include the index of the entity in the sequence column
            INSERT INTO #TBL
            SELECT
                ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS sequence,
                entity.[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
            FROM OPENJSON(@wrkspc_json_entities) WITH ([name] [nvarchar](10)) as entity;

            -- declare variables to be used in the loop
            DECLARE @wrkspc_workspace_name NVARCHAR(10);

            SET @wrkspc_entities_counter = 1;
            SET @wrkspc_entities_total = (SELECT COUNT(*) FROM #TBL);
            WHILE @wrkspc_entities_counter <= @wrkspc_entities_total
            BEGIN
                SET @wrkspc_workspace_name = (SELECT workspace_name FROM #TBL WHERE [sequence] = @wrkspc_entities_counter);
                EXEC [mgmt_xtinfra].[sp_infra_reset_workspace_object_version] @wrkspc_workspace_name;

                -- create the order for the workspace
                PRINT 'Executing workspace migration, workspace: ' + @wrkspc_workspace_name;
                EXEC [mgmt_xtinfra].[sp_infra_workspace_run_to_version] 'upgrade', 0, 9999, @wrkspc_workspace_name;

                -- increment counter
                SET @wrkspc_entities_counter = @wrkspc_entities_counter + 1;
            END
        END TRY
        BEGIN CATCH
            PRINT 'An error has been caught on post deployment script for workspaces.';

            -- drop the temp table if it's still there
            IF OBJECT_ID ('tempdb..#TBL') IS NOT NULL
                DROP TABLE #TBL;

            -- raise the error again
            THROW;
        END CATCH
    END
    ELSE
        PRINT 'Input is not detected as json. Might be empty or invalid.';
    --Removing all the temp tables which have been used during the execution
    PRINT('Removing all the temp tables which have been used during the execution');
    IF OBJECT_ID ('tempdb..#TBL') IS NOT NULL
        DROP TABLE #TBL;
    PRINT 'END: Running PostDeployment script for workspaces';
END

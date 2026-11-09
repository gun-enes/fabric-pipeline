-- Modified by Deep Network GmbH to make it compatible with Synapse
CREATE PROCEDURE [tSQLt_synapse].[RunAll]
AS
BEGIN
    TRUNCATE TABLE [tSQLt_synapse].[TestInfo];

    INSERT INTO [tSQLt_synapse].[TestInfo] ([test_name], [test_number], [object_id], [test_rollback_name])
    SELECT
        [s2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        ROW_NUMBER() OVER (ORDER BY [s2].[object_id]),
        [s2].[object_id],
        (
            SELECT [s1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 FROM [sys].[procedures] AS [s1]
            WHERE
                [s1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 LIKE N'rollback[_]%'
                AND SCHEMA_NAME([s1].[schema_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = N'UnitTests'
                AND SUBSTRING([s1].[name], LEN('rollback_') + 1, LEN([s1].[name]) - LEN('rollback_')) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = [s2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
        )
    FROM
        [sys].[procedures] AS [s2]
    WHERE
        [s2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 LIKE N'test[_]%'
        AND SCHEMA_NAME([s2].[schema_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = N'UnitTests'

    DECLARE @completed_tests int = 1;
    DECLARE @total_tests int;
    DECLARE @test_name nvarchar(MAX);
    DECLARE @rollback_name nvarchar(MAX);
    DECLARE @execute_stmt nvarchar(MAX);
    DECLARE @test_start_time datetime;
    DECLARE @test_end_time datetime;
    DECLARE @result nvarchar(7);
    DECLARE @rollback_result nvarchar(7);
    DECLARE @message nvarchar(MAX) = NULL;
    DECLARE @tmp_message nvarchar(MAX);

    SELECT @total_tests = COUNT(*) FROM [tSQLt_synapse].[TestInfo];

    IF (OBJECT_ID('tempdb..#ExpectException') IS NOT NULL)
        DROP TABLE #ExpectException;
    CREATE TABLE #ExpectException (
        [ExpectException] int,
        [ExpectedMessage] nvarchar(2048) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [ExpectedSeverity] int,
        [ExpectedState] int,
        [ExpectedErrorNumber] int,
        [FailMessage] nvarchar(2048) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    );


    WHILE (@completed_tests <= @total_tests)
        BEGIN
            SELECT
                @test_name = [test_name],
                @rollback_name = [test_rollback_name]
            FROM [tSQLt_synapse].[TestInfo]
            WHERE [test_number] = @completed_tests;
            SET @execute_stmt = N'EXEC UnitTests.[' + @test_name + ']';
            TRUNCATE TABLE #ExpectException;
            SET @message = NULL;
            IF (OBJECT_ID('tempdb..#BeforeExecutionObjectSnapshot') IS NOT NULL)
                DROP TABLE #BeforeExecutionObjectSnapshot;
            SELECT
                [object_id] AS [ObjectId],
                [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [ObjectName],
                [type_desc] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [ObjectType],
                SCHEMA_NAME([schema_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [SchemaName]
            INTO #BeforeExecutionObjectSnapshot
            FROM [sys].[objects]
            WHERE SCHEMA_NAME([schema_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN ('tSQLt_synapse', 'UnitTests', 'mgmt_xtinfra');
            SET @test_start_time = SYSDATETIME();
            BEGIN TRY
                EXEC [sp_executesql] @execute_stmt;
                IF (EXISTS (SELECT 1 FROM #ExpectException WHERE [ExpectException] = 1))
                    BEGIN
                        SET
                            @tmp_message = COALESCE((SELECT [FailMessage] FROM #ExpectException) + ' ', '')
                            + 'Expected an error to be raised.';
                        EXEC [tSQLt_synapse].[Fail] @tmp_message;
                    END
                SET @test_end_time = SYSDATETIME();
                SET @result = 'success'
            END TRY
            BEGIN CATCH
                SET @test_end_time = SYSDATETIME();
                IF (ERROR_MESSAGE() LIKE '%tSQLt_synapse.Failure%') --assertion fail
                    BEGIN
                        SET @result = 'failure';
                        SET @message = ERROR_MESSAGE();
                    END
                ELSE
                    BEGIN
                        IF (EXISTS (SELECT 1 FROM #ExpectException))
                            BEGIN
                                DECLARE @ExpectException int;
                                DECLARE @ExpectedMessage nvarchar(MAX);
                                DECLARE @ExpectedSeverity int;
                                DECLARE @ExpectedErrorNumber int;
                                DECLARE @ExpectedState int;
                                DECLARE @FailMessage nvarchar(MAX);
                                SELECT
                                    @ExpectException = [ExpectException],
                                    @ExpectedMessage = [ExpectedMessage],
                                    @ExpectedSeverity = [ExpectedSeverity],
                                    @ExpectedErrorNumber = [ExpectedErrorNumber],
                                    @ExpectedState = [ExpectedState],
                                    @FailMessage = [FailMessage]
                                FROM #ExpectException;

                                IF (@ExpectException = 1)
                                    BEGIN
                                        SET @result = 'success';
                                        IF (ERROR_MESSAGE() <> @ExpectedMessage)
                                            BEGIN
                                                SET
                                                    @message = 'Expected Message: <' + @ExpectedMessage + '>'
                                                    + ' Actual Message  : <' + ERROR_MESSAGE() + '>';
                                                SET @result = 'failure';
                                            END
                                        IF (ERROR_NUMBER() <> @ExpectedErrorNumber)
                                            BEGIN
                                                SET
                                                    @message
                                                    = 'Expected Error Number: '
                                                    + CAST(@ExpectedErrorNumber AS nvarchar(MAX))
                                                    + ' Actual Error Number  : ' + CAST(ERROR_NUMBER() AS nvarchar(MAX));
                                                SET @result = 'failure';
                                            END
                                        IF (ERROR_SEVERITY() <> @ExpectedSeverity)
                                            BEGIN
                                                SET
                                                    @message
                                                    = 'Expected Severity: ' + CAST(@ExpectedSeverity AS nvarchar(MAX))
                                                    + ' Actual Severity  : ' + CAST(ERROR_SEVERITY() AS nvarchar(MAX));
                                                SET @result = 'failure';
                                            END
                                        IF (ERROR_STATE() <> @ExpectedState)
                                            BEGIN
                                                SET
                                                    @message
                                                    = 'Expected State: ' + CAST(@ExpectedState AS nvarchar(MAX))
                                                    + ' Actual State  : ' + CAST(ERROR_STATE() AS nvarchar(MAX));
                                                SET @result = 'failure';
                                            END
                                    END
                                ELSE
                                    BEGIN
                                        SET @result = 'failure';
                                        SET
                                            @message
                                            = COALESCE(@FailMessage + ' ', '')
                                            + 'Expected no error to be raised. Instead this error was encountered: '
                                            + ERROR_MESSAGE()
                                    END
                            END
                        ELSE
                            BEGIN
                                SET @result = 'error';
                                SET @message = ERROR_MESSAGE();
                            END;
                    END
            END CATCH
            IF (@rollback_name IS NOT NULL)
                BEGIN TRY
                    SET @execute_stmt = N'EXEC UnitTests.[' + @rollback_name + ']';
                    EXEC [sp_executesql] @execute_stmt;
                    SET @rollback_result = 'success'
                END TRY
                BEGIN CATCH
                    PRINT 'Rollback ' + @rollback_name + ' terminated with exceptions.'
                    SET @rollback_result = 'failure'
                END CATCH
            ELSE
                SET @rollback_result = NULL;
            UPDATE [tSQLt_synapse].[TestInfo] SET
                [result] = @result,
                [test_start_time] = @test_start_time,
                [test_end_time] = @test_end_time,
                [result_message] = @message,
                [test_rollback_result] = @rollback_result
            WHERE [test_number] = @completed_tests;
            SET @completed_tests = @completed_tests + 1;
            IF (OBJECT_ID('tempdb..#AfterExecutionObjectSnapshot') IS NOT NULL)
                DROP TABLE #AfterExecutionObjectSnapshot;
            SELECT
                [object_id] AS [ObjectId],
                [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [ObjectName],
                [type_desc] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [ObjectType],
                SCHEMA_NAME([schema_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [SchemaName]
            INTO #AfterExecutionObjectSnapshot
            FROM [sys].[objects]
            WHERE SCHEMA_NAME([schema_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN ('tSQLt_synapse', 'UnitTests', 'mgmt_xtinfra');
            EXEC [tSQLt_synapse].[Private_AssertNoSideEffects]
                '#BeforeExecutionObjectSnapshot', '#AfterExecutionObjectSnapshot', @test_name;
        END

    EXEC [tSQLt_synapse].[Private_OutputResults];
END;

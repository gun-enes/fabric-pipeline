CREATE PROCEDURE [tSQLt_synapse].[Private_OutputResults]
AS
BEGIN
    DECLARE @test_name NVARCHAR(MAX);
    DECLARE @result NVARCHAR(7);
    DECLARE @completed_tests INT = 1;
    DECLARE @max_len_test_num INT;
    DECLARE @max_len_test_name INT;
    DECLARE @max_len_result INT;
    DECLARE @total_tests INT;
    DECLARE @success_tests INT;
    DECLARE @failure_tests INT;
    DECLARE @error_tests INT;
    DECLARE @header NVARCHAR(MAX);
    DECLARE @errors NVARCHAR(MAX) = '';
    DECLARE @message NVARCHAR(MAX);

    SELECT
        @total_tests = COUNT(*),
        @success_tests = ISNULL(SUM(CASE WHEN [result] = 'success' THEN 1 ELSE 0 END), 0),
        @failure_tests = ISNULL(SUM(CASE WHEN [result] = 'failure' THEN 1 ELSE 0 END), 0),
        @error_tests = ISNULL(SUM(CASE WHEN [result] = 'error' THEN 1 ELSE 0 END), 0)
    FROM [tSQLt_synapse].[TestInfo];

    SELECT @max_len_test_num = MAX(LEN(CAST([test_number] AS NVARCHAR(100)))) OVER ()
    FROM [tSQLt_synapse].[TestInfo];

    SELECT @max_len_test_name = MAX(LEN([test_name])) OVER () FROM [tSQLt_synapse].[TestInfo];
    SELECT @max_len_result = MAX(LEN([result])) OVER () FROM [tSQLt_synapse].[TestInfo];

    IF (LEN('No') > @max_len_test_num)
        SET @max_len_test_num = LEN('No')
    IF (LEN('Test Case Name') > @max_len_test_name)
        SET @max_len_test_name = LEN('Test Case Name')
    IF (LEN('Result') > @max_len_result)
        SET @max_len_result = LEN('Result')

    PRINT '+----------------------+';
    PRINT '|Test Execution Summary|';
    PRINT '+----------------------+';
    PRINT ' ';
    SET
        @header
        = '| No'
        + SPACE(@max_len_test_num - LEN('No') + 1)
        + ' | Test Case Name'
        + SPACE(@max_len_test_name - LEN('Test Case Name') + 1)
        + ' | Result' + SPACE(@max_len_result - LEN('Result') + 1) + ' |';
    PRINT @header;
    PRINT REPLICATE('-', LEN(@header));

    WHILE (@completed_tests <= @total_tests)
        BEGIN
            SELECT
                @test_name = [test_name],
                @result = [result],
                @message = [result_message]
            FROM [tSQLt_synapse].[TestInfo]
            WHERE [test_number] = @completed_tests;
            PRINT '| '
            + CAST(@completed_tests AS NVARCHAR(100))
            + SPACE(@max_len_test_num - LEN(CAST(@completed_tests AS NVARCHAR(100))) + 1)
            + ' | '
            + @test_name
            + SPACE(@max_len_test_name - LEN(@test_name) + 1)
            + ' | '
            + @result
            + SPACE(@max_len_result - LEN(@result) + 1)
            + ' |';
            SET @completed_tests = @completed_tests + 1;
            SET @errors = @errors + ISNULL('[' + @test_name + '] failed: ' + @message + CHAR(13) + CHAR(10), '')
        END
    PRINT REPLICATE('-', LEN(@header));
    PRINT @errors;
    PRINT '';
    PRINT 'Test Case Summary: '
    + CAST(@total_tests AS NVARCHAR(100))
    + ' test case(s) executed, '
    + CAST(@success_tests AS NVARCHAR(100))
    + ' succeeded, '
    + CAST(@failure_tests AS NVARCHAR(100))
    + ' failed, '
    + CAST(@error_tests AS NVARCHAR(100))
    + ' errored.';
    PRINT REPLICATE('-', LEN(@header));
END;

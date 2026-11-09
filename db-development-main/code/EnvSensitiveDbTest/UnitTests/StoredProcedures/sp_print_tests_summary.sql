CREATE PROCEDURE [UnitTests].[sp_print_tests_summary]
AS
BEGIN
    DECLARE
        @total_tests INT,
        @success_tests INT,
        @failure_tests INT,
        @error_tests INT;

    SELECT
        @total_tests = COUNT(*),
        @success_tests = ISNULL(SUM(CASE WHEN [result] = 'success' THEN 1 ELSE 0 END), 0),
        @failure_tests = ISNULL(SUM(CASE WHEN [result] = 'failure' THEN 1 ELSE 0 END), 0),
        @error_tests = ISNULL(SUM(CASE WHEN [result] = 'error' THEN 1 ELSE 0 END), 0)
    FROM [UnitTests].[TestStatus];

    PRINT '+----------------------+';
    PRINT '|Test Execution Summary|';
    PRINT '+----------------------+';
    PRINT ' ';

    PRINT 'Test Case Summary: '
    + CAST(@total_tests AS NVARCHAR(100))
    + ' test case(s) executed, '
    + CAST(@success_tests AS NVARCHAR(100))
    + ' succeeded, '
    + CAST(@failure_tests AS NVARCHAR(100))
    + ' failed, '
    + CAST(@error_tests AS NVARCHAR(100))
    + ' errored.';
    PRINT '------------------------------------------------------------------------------------------';

    PRINT ('---------------------------------------------');
    PRINT ('Environment Sensitive DB Test is completed...')
END

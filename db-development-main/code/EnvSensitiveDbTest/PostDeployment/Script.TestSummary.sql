BEGIN
    -- Print test summary
    EXEC [UnitTests].[sp_print_tests_summary];

    IF
        EXISTS (
            SELECT 1 FROM [UnitTests].[TestStatus]
            WHERE [result] IN ('failure', 'error')
        )
        BEGIN
            PRINT 'Test execution failed.';
            THROW 50000, 'There exists failed or errored tests!', 100;
        END;
END

-- This file contains SQL statements that will be executed after the build script.
BEGIN
    DECLARE @error_message NVARCHAR(MAX) = 'success';
    BEGIN TRY
        PRINT('Running tests');
        -- Run the created tests
        EXEC [tSQLt_synapse].[RunAll];
    END TRY
    BEGIN CATCH
        PRINT('Test run failed');
        SET @error_message = ERROR_MESSAGE();
        PRINT(@error_message);
    END CATCH

    PRINT ('Deleting tests');
    -- Delete tests
    DECLARE @drop_sprocs NVARCHAR(MAX);
    SELECT @drop_sprocs = STRING_AGG(CAST(CONCAT(N'DROP PROCEDURE [UnitTests].', QUOTENAME([name]), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)), CHAR(13))
    FROM [sys].[procedures]
    WHERE SCHEMA_NAME([schema_id]) = 'UnitTests';

    PRINT @drop_sprocs
    EXEC sys.sp_executesql @drop_sprocs;

    PRINT ('Deleting test tables');
    -- Delete test tables
    DECLARE @drop_tables NVARCHAR(MAX);
    SELECT @drop_tables = STRING_AGG(CAST(CONCAT(N'DROP TABLE [UnitTests].', QUOTENAME([name]), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)), CHAR(13))
    FROM [sys].[tables]
    WHERE SCHEMA_NAME([schema_id]) = 'UnitTests'
    AND [is_external] = 0;

    PRINT @drop_tables
    EXEC [sys].[sp_executesql] @drop_tables;

    PRINT('Deleting test schema');
    -- Delete test schema
    DROP SCHEMA [UnitTests];

    IF(@error_message <> 'success')
        THROW 50006, @error_message, 6;

    IF EXISTS (
        SELECT 1
        FROM [tSQLt_synapse].[TestInfo]
        WHERE [result] = 'failure' OR [result] = 'error'
           OR [test_rollback_result] = 'failure'
    )
        THROW 50005, 'There exist failed tests or rollbacks. Please check workflow logs for results', 5;
END

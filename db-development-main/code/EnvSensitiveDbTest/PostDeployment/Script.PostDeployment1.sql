-- This file contains SQL statements that will be executed after the build script.
BEGIN
    DECLARE @now DATETIME = GETDATE();
    DECLARE @test_result NVARCHAR(20);
    DECLARE @procedural_error NVARCHAR(100);
    DECLARE @verification_error_count INT;
    DECLARE @final_result NVARCHAR(20);

    PRINT ('---------------------------------------------');
    PRINT 'Starting environment sensitive DB test...';

    :r .\Script.RunTestCETAS.sql
    :r .\Script.TestSetupDecom.sql
    :r .\Script.RunTestDecom.sql
    :r .\Script.TestSummary.sql
END

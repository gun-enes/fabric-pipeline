BEGIN
    SET @procedural_error = 'success';
    SET @test_result = 'success';
    -- Execute backup/restore test
    BEGIN TRY
        TRUNCATE TABLE [UnitTests].[Errors];

        SET @now = GETDATE();
        INSERT INTO [UnitTests].[TestStatus]
        VALUES ('test_verification_cetas_backup_restore', '', @now, '');

        -- Execute test
        EXEC [UnitTests].[test_verification_cetas_backup_restore];

        -- Read verification result based on [UnitTests].[Errors] table
        SELECT @verification_error_count = COUNT(*) FROM [UnitTests].[Errors];
        IF @verification_error_count > 0
            SET @test_result = 'failure';
    END TRY
    BEGIN CATCH
        PRINT ('test_verification_cetas_backup_restore run failed');
        SET @procedural_error = ERROR_MESSAGE();
        PRINT (@procedural_error);
    END CATCH

    EXEC [UnitTests].[sp_print_errors];

    IF (@procedural_error <> 'success')
        SET @final_result = 'error';
    ELSE
        SET @final_result = @test_result;

    SET @now = GETDATE();
    UPDATE [UnitTests].[TestStatus]
    SET
        [result] = @final_result,
        [test_end_time] = @now
    WHERE [test_name] = 'test_verification_cetas_backup_restore';

    -- Clean the objects
    EXEC [UnitTests].[rollback_test_verification_cetas_backup_restore];
END

BEGIN
    --execute if setup did not fail
    IF
        NOT EXISTS (
            SELECT 1 FROM [UnitTests].[TestStatus]
            WHERE
                [result] = 'error'
                AND [test_name] = 'test_verification_ext_decom_functionality'
        )
        BEGIN
            SET @procedural_error = 'success';
            SET @test_result = 'success';
            -- Execute decommission test
            BEGIN TRY
                TRUNCATE TABLE [UnitTests].[Errors];

                -- Act
                -- Execute the extension decommission procedure
                PRINT 'Executing decommission for workspace: ' + @test_workspace;
                EXEC [mgmt_xtinfra].[sp_infra_ext_decom] 'decom', @test_workspace;

                -- Assert
                -- Execute the verification
                EXEC [UnitTests].[test_verification_ext_decom_functionality];

                -- Read verification result based on [UnitTests].[Errors] table
                SELECT @verification_error_count = COUNT(*) FROM [UnitTests].[Errors];
                IF @verification_error_count > 0
                    SET @test_result = 'failure';
            END TRY
            BEGIN CATCH
                PRINT ('test_verification_ext_decom_functionality run failed');
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
            WHERE [test_name] = 'test_verification_ext_decom_functionality';
        END
END;

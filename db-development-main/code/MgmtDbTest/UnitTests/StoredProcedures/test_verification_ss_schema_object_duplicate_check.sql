--Check if all self-service objects have exactly 1 row
CREATE PROCEDURE [UnitTests].[test_verification_ss_object_duplicate_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_object_duplicate_check')
    SELECT [name], [type], COUNT(*) AS [object_count]
    INTO [UnitTests].[DuplicateObjects]
    FROM [mgmt_xtinfra].[infra_object_master]
    GROUP BY [name], [type]
    HAVING COUNT(*) > 1

    PRINT ('Objects with duplicates are given below')
    -- Table should be empty if none of the schemas have duplicates
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.DuplicateObjects'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_object_duplicate_check]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_object_duplicate_check')
    DROP TABLE [UnitTests].[DuplicateObjects]
END;
GO

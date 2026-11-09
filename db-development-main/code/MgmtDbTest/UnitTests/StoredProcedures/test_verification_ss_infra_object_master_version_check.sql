--Check if all objects are in most recent version
CREATE PROCEDURE [UnitTests].[test_verification_ss_infra_object_master_version_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_infra_object_master_version_check')
    SELECT DISTINCT *
    INTO [UnitTests].[WrongVersionObjects]
    FROM [mgmt_xtinfra].[infra_object_master]
    WHERE
        ([type] = 'schema' AND [version] NOT IN (0, 4))
        OR ([type] = 'schemarole' AND [version] NOT IN (0, 1))
        OR ([type] = 'workspace' AND [version] NOT IN (0, 12))
        OR ([type] = 'user' AND [version] NOT IN (0, 1))
        OR ([type] = 'rlspolicy' AND [version] NOT IN (0, 1))
        OR ([type] = 'schemalink' AND [version] NOT IN (0, 1))
        OR ([type] = 'workloadclassifier' AND [version] NOT IN (0, 1))
        OR ([type] = 'workloadgroup' AND [version] NOT IN (0, 1))
        OR ([type] = 'killsession' AND [version] NOT IN (0, 1))

    PRINT ('Incorrect versioned objects are given below')
    -- Table should be empty if all objects are in correct version
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.WrongVersionObjects'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_infra_object_master_version_check]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_infra_object_master_version_check')
    DROP TABLE [UnitTests].[WrongVersionObjects]
END;
GO

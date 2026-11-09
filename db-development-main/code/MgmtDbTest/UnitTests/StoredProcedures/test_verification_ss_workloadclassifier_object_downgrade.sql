--Test self service workloadclassifier object upgrade
CREATE PROCEDURE [UnitTests].[test_verification_ss_workloadclassifier_object_downgrade]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_workloadclassifier_object_downgrade');
    -- create a clasiffier to be deleted
    CREATE WORKLOAD CLASSIFIER [tSQLt_wc_downgrade]
    WITH (
        WORKLOAD_GROUP = 'smallrc',
        MEMBERNAME = 'dbo'
    );

    -- to execute downgrade, object should exist in table
    INSERT INTO [mgmt_xtinfra].[infra_object_master]
    VALUES('workloadclassifier', 'tSQLt_wc_downgrade', 1)

    -- downgrade classifier
    EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_run_to_version] 'downgrade', 9999, 0, 'tSQLt_wc_downgrade', '', '', '', '', '', '', '';
    DECLARE @workloadclassifier_deleted INT = 1;

    SELECT @workloadclassifier_deleted = 0
    FROM [sys].[workload_management_workload_classifiers]
    WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_wc_downgrade'

    -- If workloadclassifier is not deleted, select will return 0
    EXEC [tSQLt_synapse].[AssertEqualsInt] 1, @workloadclassifier_deleted;
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_workloadclassifier_object_downgrade]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_workloadclassifier_object_downgrade');

    IF EXISTS (SELECT 1 FROM [sys].[workload_management_workload_classifiers] WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_wc_downgrade')
        DROP WORKLOAD CLASSIFIER "tSQLt_wc_downgrade";
    DELETE FROM [mgmt_xtinfra].[infra_object_master]
    WHERE [name] = 'tSQLt_wc_downgrade'
END;
GO

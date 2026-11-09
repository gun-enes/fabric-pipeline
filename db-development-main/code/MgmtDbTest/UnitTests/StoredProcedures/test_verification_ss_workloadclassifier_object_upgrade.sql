--Test self service workloadclassifier object upgrade
CREATE PROCEDURE [UnitTests].[test_verification_ss_workloadclassifier_object_upgrade]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_workloadclassifier_object_upgrade');
    EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_run_to_version]
        'upgrade', 0, 9999, 'tSQLt_wc_upgrade', 'smallrc', 'dbo', 'label', 'context', '11:00', '13:00', 'LOW';
    DECLARE @workloadclassifier_created INT = 0;

    SELECT @workloadclassifier_created = 1
    FROM [sys].[workload_management_workload_classifiers]
    WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_wc_upgrade'

    -- If workloadclassifier is created, select will return 1
    EXEC [tSQLt_synapse].[AssertEqualsInt] 1, @workloadclassifier_created;

    CREATE TABLE [#ExpectedClassifierDetails] (
        [name] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [group_name] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [importance] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [classifier_type] NVARCHAR(255) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [classifier_value] NVARCHAR(255) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = HASH ([name]));

    INSERT INTO [#ExpectedClassifierDetails]
    VALUES ('tSQLt_wc_upgrade', 'smallrc', 'low', 'end_time', '13:00');

    INSERT INTO [#ExpectedClassifierDetails]
    VALUES ('tSQLt_wc_upgrade', 'smallrc', 'low', 'start_time', '11:00');

    INSERT INTO [#ExpectedClassifierDetails]
    VALUES ('tSQLt_wc_upgrade', 'smallrc', 'low', 'membername', 'dbo');

    INSERT INTO [#ExpectedClassifierDetails]
    VALUES ('tSQLt_wc_upgrade', 'smallrc', 'low', 'wlm_label', 'label');

    INSERT INTO [#ExpectedClassifierDetails]
    VALUES ('tSQLt_wc_upgrade', 'smallrc', 'low', 'wlm_context', 'context');

    -- Get missing workload classifier details
    SELECT
        [name],
        [group_name],
        [importance],
        [classifier_type],
        [classifier_value]
    INTO [UnitTests].[MissingClassifierDetails]
    FROM [#ExpectedClassifierDetails]
    EXCEPT
    SELECT
        [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [group_name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [importance] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [classifier_type] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [classifier_value] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    FROM [sys].[workload_management_workload_classifiers] AS [wc]
    INNER JOIN [sys].[workload_management_workload_classifier_details] AS [wcd]
        ON [wc].[classifier_id] = [wcd].[classifier_id]
    WHERE [wc].[name] = 'tSQLt_wc_upgrade' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8

    PRINT ('Workload classifier details that are missing are given below')
    -- Table should be empty if all workload classifier is created with correct details
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.MissingClassifierDetails'

    -- Test update workload classifier
    EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_run_to_version]
        'upgrade', 0, 9999, 'tSQLt_wc_upgrade', 'smallrc', 'dbo', 'label2', 'context2', '06:00', '19:00', 'HIGH';
    SET @workloadclassifier_created = 0;

    SELECT @workloadclassifier_created = 1
    FROM [sys].[workload_management_workload_classifiers]
    WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_wc_upgrade'

    -- If workloadclassifier is created, select will return 1
    EXEC [tSQLt_synapse].[AssertEqualsInt] 1, @workloadclassifier_created;

    TRUNCATE TABLE [#ExpectedClassifierDetails];

    INSERT INTO [#ExpectedClassifierDetails]
    VALUES ('tSQLt_wc_upgrade', 'smallrc', 'HIGH', 'end_time', '19:00');

    INSERT INTO [#ExpectedClassifierDetails]
    VALUES ('tSQLt_wc_upgrade', 'smallrc', 'HIGH', 'start_time', '06:00');

    INSERT INTO [#ExpectedClassifierDetails]
    VALUES ('tSQLt_wc_upgrade', 'smallrc', 'HIGH', 'membername', 'dbo');

    INSERT INTO [#ExpectedClassifierDetails]
    VALUES ('tSQLt_wc_upgrade', 'smallrc', 'HIGH', 'wlm_label', 'label2');

    INSERT INTO [#ExpectedClassifierDetails]
    VALUES ('tSQLt_wc_upgrade', 'smallrc', 'HIGH', 'wlm_context', 'context2');

    -- Get missing workload classifier details
    SELECT
        [name],
        [group_name],
        [importance],
        [classifier_type],
        [classifier_value]
    INTO [UnitTests].[MissingClassifierDetailsAlter]
    FROM [#ExpectedClassifierDetails]
    EXCEPT
    SELECT
        [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [group_name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [importance] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [classifier_type] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [classifier_value] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    FROM [sys].[workload_management_workload_classifiers] AS [wc]
    INNER JOIN [sys].[workload_management_workload_classifier_details] AS [wcd]
        ON [wc].[classifier_id] = [wcd].[classifier_id]
    WHERE [wc].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_wc_upgrade'

    PRINT ('Workload classifier details that are missing are given below')
    -- Table should be empty if all workload classifier is created with correct details
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.MissingClassifierDetailsAlter'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_workloadclassifier_object_upgrade]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_workloadclassifier_object_upgrade');

    IF EXISTS (SELECT 1 FROM [sys].[workload_management_workload_classifiers] WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_wc_upgrade')
        DROP WORKLOAD CLASSIFIER "tSQLt_wc_upgrade";

    IF OBJECT_ID('UnitTests.MissingClassifierDetails') IS NOT NULL
    BEGIN
        DROP TABLE [UnitTests].[MissingClassifierDetails];
    END

    IF OBJECT_ID('UnitTests.MissingClassifierDetailsAlter') IS NOT NULL
    BEGIN
        DROP TABLE [UnitTests].[MissingClassifierDetailsAlter];
    END

    DELETE FROM [mgmt_xtinfra].[infra_object_master]
    WHERE [name] = 'tSQLt_wc_upgrade'
END;
GO

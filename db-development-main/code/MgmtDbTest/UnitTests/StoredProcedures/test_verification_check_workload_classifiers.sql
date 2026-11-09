--Check if all workload classifiers have been created
CREATE PROCEDURE [UnitTests].[test_verification_check_workload_classifiers]
AS
BEGIN
    PRINT ('Executing Test: test_verification_check_workload_classifiers');

    CREATE TABLE [#ExpectedWorkloadClassifiers] (
        [name] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [group_name] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [member_name] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [importance] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
    )
    WITH (DISTRIBUTION = ROUND_ROBIN);

    -- dbo classifier
    INSERT INTO [#ExpectedWorkloadClassifiers]
    VALUES ('wc_dbo', 'adhoc_group', 'dbo', 'HIGH');

    -- adhoc classifier
    INSERT INTO [#ExpectedWorkloadClassifiers]
    VALUES ('wc_adhoc_group', 'adhoc_group', 'Role_AdhocGroupClassifier', 'HIGH');

    -- other classifier
    INSERT INTO [#ExpectedWorkloadClassifiers]
    VALUES ('wc_other_group', 'other_group', 'Role_OtherGroupClassifier', 'HIGH');

    -- critcal classifier
    INSERT INTO [#ExpectedWorkloadClassifiers]
    VALUES ('wc_critical_group', 'critical_group', 'Role_CriticalGroupClassifier', 'HIGH');

    -- repo classifier
    INSERT INTO [#ExpectedWorkloadClassifiers]
    VALUES ('wc_repo_group', 'repo_group', 'Role_RepoGroupClassifier', 'HIGH');

    SELECT
        [name],
        [group_name],
        [member_name],
        [importance]
    INTO [UnitTests].[MissingDefaultClassifiers]
    FROM [#ExpectedWorkloadClassifiers]
    EXCEPT
    SELECT
        [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [name],
        [group_name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [group_name],
        [classifier_value] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [member_name],
        [importance] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [importance]
    FROM [sys].[workload_management_workload_classifiers] AS [classifiers]
    INNER JOIN
        [sys].[workload_management_workload_classifier_details] AS [details]
        ON [classifiers].[classifier_id] = [details].[classifier_id]
    WHERE
        [details].[classifier_type] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'membername'
        --exclude default classifiers https://learn.microsoft.com/en-us/azure/synapse-analytics/sql-data-warehouse/sql-data-warehouse-workload-classification#system-classifiers
        AND [classifiers].[classifier_id] > 12

    PRINT ('Default workload classifiers that are missing are given below.')
    -- Table should be empty if all default workload classifiers exist
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.MissingDefaultClassifiers'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_check_workload_classifiers]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_check_workload_classifiers')
    DROP TABLE [UnitTests].[MissingDefaultClassifiers]
END;
GO

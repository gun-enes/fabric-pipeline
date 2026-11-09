--Test self service workloadgroup object downgrade
CREATE PROCEDURE [UnitTests].[test_verification_ss_workloadgroup_object_downgrade]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_workloadgroup_object_downgrade')
    -- create a group to be deleted
    CREATE WORKLOAD GROUP [tSQLt_wg_downgrade]
    WITH
    ( MIN_PERCENTAGE_RESOURCE = 0
    , REQUEST_MIN_RESOURCE_GRANT_PERCENT = 5
    , CAP_PERCENTAGE_RESOURCE = 100
    , REQUEST_MAX_RESOURCE_GRANT_PERCENT = 75 )

    -- to execute downgrade, object should exist in table
    INSERT INTO [mgmt_xtinfra].[infra_object_master]
    VALUES('workloadgroup', 'tSQLt_wg_downgrade', 1)

    -- downgrade group
    EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'downgrade', 9999, 0, 'tSQLt_wg_downgrade', 0, 0, 0, NULL, NULL, NULL
    DECLARE @group_deleted INT = 1;

    SELECT @group_deleted = 0
    FROM [sys].[workload_management_workload_groups]
    WHERE
        [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_wg_downgrade'
        AND [min_percentage_resource] = 0
        AND [cap_percentage_resource] = 100
        AND [request_min_resource_grant_percent] = 5
        AND [request_max_resource_grant_percent] = 75

    -- If group is created, select will return 1
    EXEC [tSQLt_synapse].[AssertEqualsInt] 1, @group_deleted;
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_workloadgroup_object_downgrade]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_workloadgroup_object_downgrade')
    DELETE FROM [mgmt_xtinfra].[infra_object_master]
    WHERE [name] = 'tSQLt_wg_downgrade'

    IF
        EXISTS (
            SELECT 1
            FROM [sys].[workload_management_workload_groups]
            WHERE
                [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_wg_downgrade'
        )
        DROP WORKLOAD GROUP [tSQLt_wg_downgrade];
END;
GO

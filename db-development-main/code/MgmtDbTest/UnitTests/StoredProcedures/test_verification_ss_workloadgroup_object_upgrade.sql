--Test self service workloadgroup object upgrade
CREATE PROCEDURE [UnitTests].[test_verification_ss_workloadgroup_object_upgrade]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_workloadgroup_object_upgrade')
    EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'upgrade', 0, 9999, 'tSQLt_workloadgroup', 0, 75, 5, 75, NULL, NULL
    DECLARE @group_found INT = 0;

    SELECT @group_found = 1
    FROM [sys].[workload_management_workload_groups]
    WHERE
        [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_workloadgroup'
        AND [min_percentage_resource] = 0
        AND [cap_percentage_resource] = 75
        AND [request_min_resource_grant_percent] = 5
        AND [request_max_resource_grant_percent] = 75

    -- If group is created, select will return 1
    EXEC [tSQLt_synapse].[AssertEqualsInt] 1, @group_found;

    -- Test update workload group by changing a parameter value
    EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'upgrade', 0, 9999, 'tSQLt_workloadgroup', 0, 100, 5, 75, NULL, NULL
    SET @group_found = 0;
    SELECT @group_found = 1
    FROM [sys].[workload_management_workload_groups]
    WHERE
        [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_workloadgroup'
        AND [min_percentage_resource] = 0
        AND [cap_percentage_resource] = 100
        AND [request_min_resource_grant_percent] = 5
        AND [request_max_resource_grant_percent] = 75

    -- If group is created, select will return 1
    EXEC [tSQLt_synapse].[AssertEqualsInt] 1, @group_found;
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_workloadgroup_object_upgrade]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_workloadgroup_object_upgrade')

    IF
        EXISTS (
            SELECT 1
            FROM [sys].[workload_management_workload_groups]
            WHERE
                [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_workloadgroup'
        )
        DROP WORKLOAD GROUP [tSQLt_workloadgroup];

    DELETE FROM [mgmt_xtinfra].[infra_object_master]
    WHERE [name] = 'tSQLt_workloadgroup';
END;
GO

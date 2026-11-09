
    -- Changing the Workload Group REQUEST_MAX_RESOURCE_GRANT_PERCENT to 75
BEGIN
    PRINT 'Changing the Workload Group REQUEST_MAX_RESOURCE_GRANT_PERCENT to 75';

    IF NOT EXISTS (
        SELECT 1
        FROM mgmt_xtinfra.infra_orders_details_workloadgroup
        WHERE group_name = 'adhoc_group'
    )
    BEGIN
        EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'upgrade', 0, 9999, 'adhoc_group', 0, 100, 3, 75, 'NORMAL', NULL;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM mgmt_xtinfra.infra_orders_details_workloadgroup
        WHERE group_name = 'other_group'
    )
    BEGIN
        EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'upgrade', 0, 9999, 'other_group', 0, 100, 1, 75, 'LOW', NULL;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM mgmt_xtinfra.infra_orders_details_workloadgroup
        WHERE group_name = 'critical_group'
    )
    BEGIN
        EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'upgrade', 0, 9999, 'critical_group', 0, 100, 8, 75, 'ABOVE_NORMAL', NULL;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM mgmt_xtinfra.infra_orders_details_workloadgroup
        WHERE group_name = 'repo_group'
    )
    BEGIN
        EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'upgrade', 0, 9999, 'repo_group', 0, 100, 8, 75, 'HIGH', NULL;
    END
END

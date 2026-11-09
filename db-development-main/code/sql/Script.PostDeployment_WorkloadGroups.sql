BEGIN
    DECLARE @default_workload_groups_created_key_name NVARCHAR(128) = 'default_workload_groups_created';
    IF
        NOT EXISTS (
            SELECT 1
            FROM [mgmt_xtinfra].[infra_global_config]
            WHERE [key] = @default_workload_groups_created_key_name
        )
        BEGIN
            PRINT 'Started creating default workload groups';

            EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'upgrade', 0, 9999, 'adhoc_group', 0, 100, 3, 75, 'NORMAL', NULL;
            EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'upgrade', 0, 9999, 'other_group', 0, 100, 1, 75, 'LOW', NULL;
            EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'upgrade', 0, 9999, 'critical_group', 0, 100, 8, 75, 'ABOVE_NORMAL', NULL;
            EXEC [mgmt_xtinfra].[sp_infra_workloadgroup_run_to_version] 'upgrade', 0, 9999, 'repo_group', 0, 100, 8, 75, 'HIGH', NULL;

            EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] @default_workload_groups_created_key_name, '1';

            PRINT 'Finished creating default workload groups';
        END
END

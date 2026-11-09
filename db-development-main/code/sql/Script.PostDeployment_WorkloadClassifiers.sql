BEGIN
    DECLARE @wc_group_name NVARCHAR(128);
    DECLARE @default_wc_created_key_name NVARCHAR(100) = 'default_workloadclassifier_created_dbo';

    PRINT ('Started creating all Workload Classifiers');

    -- dbo
    IF NOT EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = @default_wc_created_key_name
    )
    BEGIN
        PRINT ('Started creating dbo Workload Classifier');

        EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_run_to_version]
            'upgrade', 0, 9999, 'wc_dbo', 'adhoc_group', 'dbo', NULL, NULL, NULL, NULL, 'HIGH'

        EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] @default_wc_created_key_name, '1'
    END

    -- adhoc_group
    SET @default_wc_created_key_name = 'default_workloadclassifier_created_adhoc_group';

    IF NOT EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = @default_wc_created_key_name
    )
    BEGIN
        PRINT ('Started creating adhoc_group Workload Classifier');

        EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_run_to_version]
            'upgrade', 0, 9999, 'wc_adhoc_group', 'adhoc_group', 'Role_AdhocGroupClassifier', NULL, NULL, NULL, NULL, 'HIGH'

        EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] @default_wc_created_key_name, '1'
    END

    -- other_group
    SET @default_wc_created_key_name = 'default_workloadclassifier_created_other_group';

    IF NOT EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = @default_wc_created_key_name
    )
    BEGIN
        PRINT ('Started creating other_group Workload Classifier');

        EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_run_to_version]
            'upgrade', 0, 9999, 'wc_other_group', 'other_group', 'Role_OtherGroupClassifier', NULL, NULL, NULL, NULL, 'HIGH'

        EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] @default_wc_created_key_name, '1'
    END

    -- critical_group
    SET @default_wc_created_key_name = 'default_workloadclassifier_created_critical_group';

    IF NOT EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = @default_wc_created_key_name
    )
    BEGIN
        PRINT ('Started creating critical_group Workload Classifier');

        EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_run_to_version]
            'upgrade', 0, 9999, 'wc_critical_group', 'critical_group', 'Role_CriticalGroupClassifier', NULL, NULL, NULL, NULL, 'HIGH'

        EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] @default_wc_created_key_name, '1'
    END

    -- repo_group
    SET @default_wc_created_key_name = 'default_workloadclassifier_created_repo_group';

    IF NOT EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = @default_wc_created_key_name
    )
    BEGIN
        PRINT ('Started creating repo_group Workload Classifier');

        EXEC [mgmt_xtinfra].[sp_infra_workloadclassifier_run_to_version]
            'upgrade', 0, 9999, 'wc_repo_group', 'repo_group', 'Role_RepoGroupClassifier', NULL, NULL, NULL, NULL, 'HIGH'

        EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] @default_wc_created_key_name, '1'
    END

    PRINT ('Finished creating all Workload Classifiers');
END

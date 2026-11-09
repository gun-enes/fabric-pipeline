--Check if all workload groups have been created
CREATE PROCEDURE [UnitTests].[test_verification_check_workload_groups]
AS
BEGIN
    IF
        NOT EXISTS (
            SELECT 1
            FROM [mgmt_xtinfra].[infra_orders_master]
            WHERE [type] = 'workloadgroup'
        )
        BEGIN
            PRINT ('Executing Test: test_verification_check_workload_groups');

            CREATE TABLE [#ExpectedWorkloadGroups] (
                [name] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
                [importance] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
                [min_percentage_resource] INT,
                [cap_percentage_resource] INT,
                [request_min_resource_grant_percent] INT,
                [request_max_resource_grant_percent] INT
            )
            WITH (DISTRIBUTION = ROUND_ROBIN);

            INSERT INTO [#ExpectedWorkloadGroups]
            VALUES ('adhoc_group', 'NORMAL', 0, 100, 3, 75);

            INSERT INTO [#ExpectedWorkloadGroups]
            VALUES ('other_group', 'LOW', 0, 100, 1, 75);

            INSERT INTO [#ExpectedWorkloadGroups]
            VALUES ('critical_group', 'ABOVE_NORMAL', 0, 100, 8, 75);

            INSERT INTO [#ExpectedWorkloadGroups]
            VALUES ('repo_group', 'HIGH', 0, 100, 8, 75);

            SELECT
                [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [name],
                [importance] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [importance],
                [min_percentage_resource] AS [min_percentage_resource],
                [cap_percentage_resource] AS [cap_percentage_resource],
                [request_min_resource_grant_percent] AS [request_min_resource_grant_percent],
                [request_max_resource_grant_percent] AS [request_max_resource_grant_percent]
            INTO [#ExistingWorkloadGroups]
            FROM [sys].[workload_management_workload_groups]
            --exclude default groups same as tbe classifier example here https://learn.microsoft.com/en-us/azure/synapse-analytics/sql-data-warehouse/sql-data-warehouse-workload-classification#system-classifiers
            WHERE [group_id] > 12

            PRINT (
                'The difference between existing and expected Workload Groups are below. _m_ column denotes whether the expected workload group is missing (<), unexpected workload group (>) or correct assignment (=)'
            )
            -- Tables should be equal if all workload groups have been created correctly
            EXEC [tSQLt_synapse].[AssertEqualsTable] '#ExpectedWorkloadGroups', '#ExistingWorkloadGroups'
        END
END;
GO

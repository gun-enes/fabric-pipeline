--Test self service schemalink object upgrade
CREATE PROCEDURE [UnitTests].[test_verification_ss_schemalink_object_upgrade]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_schemalink_object_upgrade')
    CREATE ROLE "tSQLt_source_sch-schema-test_member";
    CREATE ROLE "tSQLt_dest_sch-schema-test_role";
    EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version] 'upgrade', 0, 9999, 'tSQLt_source_sch', 'test_member', 'tSQLt_dest_sch', 'test_role'
    DECLARE @member_assigned INT = 0;

    SELECT @member_assigned = 1
    FROM [sys].[database_role_members] AS [DRM]
    RIGHT OUTER JOIN [sys].[database_principals] AS [DP1]
    ON [DRM].[role_principal_id] = [DP1].[principal_id]
    LEFT OUTER JOIN [sys].[database_principals] AS [DP2]
    ON [DRM].[member_principal_id] = [DP2].[principal_id]
    WHERE [DP1].[type] = 'R'
    AND [DP1].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_dest_sch-schema-test_role'
    AND [DP2].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_source_sch-schema-test_member'

    -- If correct membership is assigned, select will return 1
    EXEC [tSQLt_synapse].[AssertEqualsInt] 1, @member_assigned
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_schemalink_object_upgrade]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_schemalink_object_upgrade')

    IF
        EXISTS (
            SELECT 1
            FROM [sys].[database_principals]
            WHERE [name] = 'tSQLt_source_sch-schema-test_member'
        )
        BEGIN
            DROP ROLE "tSQLt_source_sch-schema-test_member";
        END;

    IF
        EXISTS (
            SELECT 1
            FROM [sys].[database_principals]
            WHERE [name] = 'tSQLt_dest_sch-schema-test_role'
        )
        BEGIN
            DROP ROLE "tSQLt_dest_sch-schema-test_role";
        END;

    DELETE FROM [mgmt_xtinfra].[infra_object_master]
    WHERE [name] = 'tSQLt_source_sch-schema-test_member_to_tSQLt_dest_sch-schema-test_role'
END;
GO

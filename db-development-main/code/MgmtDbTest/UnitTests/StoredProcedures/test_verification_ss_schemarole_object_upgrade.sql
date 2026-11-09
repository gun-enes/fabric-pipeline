--Test self service schemarole object upgrade
CREATE PROCEDURE [UnitTests].[test_verification_ss_schemarole_object_upgrade]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_schemarole_object_upgrade')
    EXEC [mgmt_xtinfra].[sp_infra_schemarole_run_to_version] 'upgrade', 0, 9999, 'tSQLt_schemarole', 'test_role'
    DECLARE @role_found INT = 0;

    SELECT @role_found = 1
    FROM [sys].[database_principals]
    WHERE [type] = 'R'
    AND [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_schemarole-schema-test_role'

    -- If role is created, select will return 1
    EXEC [tSQLt_synapse].[AssertEqualsInt] 1, @role_found
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_schemarole_object_upgrade]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_schemarole_object_upgrade')

    IF
        EXISTS (
            SELECT 1
            FROM [sys].[database_principals]
            WHERE [name] = 'tSQLt_schemarole-schema-test_role'
        )
        BEGIN
            DROP ROLE "tSQLt_schemarole-schema-test_role";
        END;

    DELETE FROM [mgmt_xtinfra].[infra_object_master]
    WHERE [name] = 'tSQLt_schemarole-schema-test_role'
END;
GO

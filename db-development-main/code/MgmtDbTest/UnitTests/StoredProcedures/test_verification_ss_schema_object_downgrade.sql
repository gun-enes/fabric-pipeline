--Test self service schema object downgrade
CREATE PROCEDURE [UnitTests].[test_verification_ss_schema_object_downgrade]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_schema_object_downgrade');
    EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] 'upgrade', 0, 9999, 'tSQLt_sch_downgrade';
    DECLARE @schema_check INT = 0;

    SELECT @schema_check = 1
    FROM [sys].[schemas]
    WHERE [name] = 'tSQLt_sch_downgrade';

    -- If schema is created, select will return 1
    EXEC [tSQLt_synapse].[AssertEqualsInt] 1, @schema_check;

    -- performing schema downgrading
    EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] 'downgrade', 9999, 0, 'tSQLt_sch_downgrade';

    -- Check if roles are dropped
    DECLARE @role_check INT = 0;
    SELECT @role_check = 1
    FROM [sys].[database_principals] WHERE [name] LIKE 'tSQLt_sch_downgrade%';

    -- If roles are not dropped as expected , select will return 1
    EXEC [tSQLt_synapse].[AssertEqualsInt] 0, @role_check;

    SET @schema_check = 0;

    SELECT @schema_check = 1
    FROM [sys].[schemas]
    WHERE [name] = 'tSQLt_sch_downgrade';

    -- If schema is not dropped, select will set 1 to schema_check variable
    EXEC [tSQLt_synapse].[AssertEqualsInt] 0, @schema_check;
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_schema_object_downgrade]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_schema_object_downgrade');

    IF
        EXISTS (
            SELECT 1
            FROM [sys].[database_principals]
            WHERE [name] IN ('tSQLt_sch_downgrade-schema-reader', 'tSQLt_sch_downgrade-schema-writer', 'tSQLt_sch_downgrade-schema-deployer')
        )
        BEGIN
            DROP ROLE [tSQLt_sch_downgrade-schema-reader];
            DROP ROLE [tSQLt_sch_downgrade-schema-writer];
            DROP ROLE [tSQLt_sch_downgrade-schema-deployer];
        END;

    IF
        EXISTS (
            SELECT 1
            FROM [sys].[schemas]
            WHERE [name] = 'tSQLt_sch_downgrade'
        )
        BEGIN
            DROP SCHEMA [tSQLt_sch_downgrade];
        END;

    DELETE FROM [mgmt_xtinfra].[infra_object_master]
    WHERE [name] LIKE 'tSQLt_sch_downgrade%';
END;
GO

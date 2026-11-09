--Check if all schema roles have correct naming format
CREATE PROCEDURE [UnitTests].[test_verification_ss_schemarole_object_naming_format_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_schemarole_object_naming_format_check')
    SELECT DISTINCT * INTO [UnitTests].[WrongSchemaRolesNamingFormat] FROM [mgmt_xtinfra].[infra_object_master] WHERE
        [type] = 'schemarole' AND [version] <> 0
        AND [name] NOT IN
        (
            SELECT LEFT(name,40) + '-schema-writer'
            FROM [mgmt_xtinfra].[infra_object_master]
            WHERE [type] = 'schema' AND [version] <> 0
        )
        AND [name] NOT IN
        (
            SELECT LEFT(name,40) + '-schema-reader'
            FROM [mgmt_xtinfra].[infra_object_master]
            WHERE [type] = 'schema' AND [version] <> 0
        )
        AND [name] NOT IN
        (
            SELECT LEFT(name,40) + '-schema-deployer'
            FROM [mgmt_xtinfra].[infra_object_master]
            WHERE [type] = 'schema' AND [version] <> 0
        )

    PRINT ('Schema roles with incorrect naming format are given below')
    -- Table should be empty if all schema roles have correct naming format
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.WrongSchemaRolesNamingFormat'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_schemarole_object_naming_format_check]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_schemarole_object_naming_format_check')
    DROP TABLE [UnitTests].[WrongSchemaRolesNamingFormat]
END;
GO

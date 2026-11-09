--Check if all schemas have 3 particular schema roles
CREATE PROCEDURE [UnitTests].[test_verification_ss_schema_object_has_particular_schemaroles_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_schema_object_has_particular_schemaroles_check')
    SELECT
        [type],
        [name],
        [version]
    INTO [UnitTests].[WrongSchemaRolesForSchema]
    FROM [mgmt_xtinfra].[infra_object_master]
    WHERE
        [type] = 'schema'
        AND [version] <> 0

    EXCEPT

    SELECT
        [sch].[type],
        [sch].[name],
        [sch].[version]
    FROM [mgmt_xtinfra].[infra_object_master] AS [sch]
    INNER JOIN
        [mgmt_xtinfra].[infra_object_master] AS [srole]
        ON
            [srole].[name] = LEFT([sch].[name],40) + '-schema-reader'
            AND [srole].[type] = 'schemarole'
            AND [srole].[version] <> 0
    INNER JOIN
        [mgmt_xtinfra].[infra_object_master] AS [srole2]
        ON
            [srole2].[name] = LEFT([sch].[name],40) + '-schema-writer'
            AND [srole2].[type] = 'schemarole'
            AND [srole2].[version] <> 0
    INNER JOIN
        [mgmt_xtinfra].[infra_object_master] AS [srole3]
        ON
            [srole3].[name] = LEFT([sch].[name],40) + '-schema-deployer'
            AND [srole3].[type] = 'schemarole'
            AND [srole3].[version] <> 0
    WHERE
        [sch].[type] = 'schema'
        AND [sch].[version] <> 0

    PRINT ('Schemas that do not have particular 3 schema roles are given below')
    -- Table should be empty if all schemas have 3 particular schemaroles
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.WrongSchemaRolesForSchema'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_schema_object_has_particular_schemaroles_check]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_schema_object_has_particular_schemaroles_check')
    DROP TABLE [UnitTests].[WrongSchemaRolesForSchema]
END;
GO

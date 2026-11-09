--Test self service schema object upgrade
CREATE PROCEDURE [UnitTests].[test_verification_ss_schema_object_upgrade]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_schema_object_upgrade');
    EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version] 'upgrade', 0, 9999, 'tSQLt_sch_upgrade';
    DECLARE @schema_created INT = 0;

    SELECT @schema_created = 1
    FROM [sys].[schemas]
    WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_sch_upgrade'

    -- If schema is created, select will return 1
    EXEC [tSQLt_synapse].[AssertEqualsInt] 1, @schema_created;

    DECLARE @permission_assigned NVARCHAR(500);

    SELECT @permission_assigned = STRING_AGG(CAST(TRIM([permissions].[type] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8) AS NVARCHAR(MAX)), ',')
    WITHIN GROUP (ORDER BY [permissions].[type])
    FROM [sys].[database_principals] AS [users]
    INNER JOIN [sys].[database_permissions] AS [permissions]
    ON [users].[principal_id] = [permissions].[grantee_principal_id]
    AND [permissions].[state] = 'G'
    AND [permissions].[class] = 3
    AND [users].[type] = 'R'
    AND [users].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_sch_upgrade-schema-reader'
    AND SCHEMA_NAME([permissions].[major_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_sch_upgrade'

    EXEC [tSQLt_synapse].[AssertEqualsString] 'SL,VW', @permission_assigned;

    SELECT @permission_assigned = STRING_AGG(CAST(TRIM([permissions].[type] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8) AS NVARCHAR(MAX)), ',')
    WITHIN GROUP (ORDER BY [permissions].[type])
    FROM [sys].[database_principals] AS [users]
    INNER JOIN [sys].[database_permissions] AS [permissions]
    ON [users].[principal_id] = [permissions].[grantee_principal_id]
    AND [permissions].[state] = 'G'
    AND [permissions].[class] = 3
    AND [users].[type] = 'R'
    AND [users].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_sch_upgrade-schema-writer'
    AND SCHEMA_NAME([permissions].[major_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_sch_upgrade'

    EXEC [tSQLt_synapse].[AssertEqualsString] 'AL,DL,EX,IN,RF,SL,UP,VW', @permission_assigned;

    SELECT @permission_assigned = STRING_AGG(CAST(TRIM([permissions].[type] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8) AS NVARCHAR(MAX)), ',')
    WITHIN GROUP (ORDER BY [permissions].[type])
    FROM [sys].[database_principals] AS [users]
    INNER JOIN [sys].[database_permissions] AS [permissions]
    ON [users].[principal_id] = [permissions].[grantee_principal_id]
    AND [permissions].[state] = 'G'
    AND [permissions].[class] = 0
    AND [users].[type] = 'R'
    AND [users].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_sch_upgrade-schema-writer'
    AND DB_NAME([permissions].[major_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = DB_NAME()

    EXEC [tSQLt_synapse].[AssertEqualsString] 'CRFN,CRPR,CRTB,CRVW', @permission_assigned;

    SELECT @permission_assigned = STRING_AGG(CAST(TRIM([permissions].[type] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8) AS NVARCHAR(MAX)), ',')
    WITHIN GROUP (ORDER BY [permissions].[type])
    FROM [sys].[database_principals] AS [users]
    INNER JOIN [sys].[database_permissions] AS [permissions]
    ON [users].[principal_id] = [permissions].[grantee_principal_id]
    AND [permissions].[state] = 'G'
    AND [permissions].[class] = 3
    AND [users].[type] = 'R'
    AND [users].[name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_sch_upgrade-schema-deployer'
    AND SCHEMA_NAME([permissions].[major_id]) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tSQLt_sch_upgrade'

    EXEC [tSQLt_synapse].[AssertEqualsString] 'AL,CL', @permission_assigned;
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_schema_object_upgrade]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_schema_object_upgrade');
    IF
        EXISTS (
            SELECT 1
            FROM [sys].[database_principals]
            WHERE [name] IN ('tSQLt_sch_upgrade-schema-reader', 'tSQLt_sch_upgrade-schema-writer', 'tSQLt_sch_upgrade-schema-deployer')
        )
        BEGIN
            DROP ROLE [tSQLt_sch_upgrade-schema-reader];
            DROP ROLE [tSQLt_sch_upgrade-schema-writer];
            DROP ROLE [tSQLt_sch_upgrade-schema-deployer]
        END;

    IF
        EXISTS (
            SELECT 1
            FROM [sys].[schemas]
            WHERE [name] = 'tSQLt_sch_upgrade'
        )
        BEGIN
            DROP SCHEMA "tSQLt_sch_upgrade";
        END;

    DELETE FROM [mgmt_xtinfra].[infra_object_master]
    WHERE [name] LIKE 'tSQLt_sch_upgrade%'
END;
GO

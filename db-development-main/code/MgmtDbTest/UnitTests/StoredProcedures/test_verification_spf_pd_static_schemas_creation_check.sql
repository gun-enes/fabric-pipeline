--Test SPF static core and extension schema creations
CREATE PROCEDURE [UnitTests].[test_verification_spf_pd_static_schemas_creation_check]
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = 'runtime_mode' and [value] = 'SPF'
    )
    BEGIN
        PRINT ('Executing Test: test_verification_spf_pd_static_schemas_creation_check');

        IF OBJECT_ID('tempdb..#StaticSchemas') IS NOT NULL
            DROP TABLE [#StaticSchemas];

        SELECT [t].[schema_name]
        INTO [#StaticSchemas]
        FROM (
                SELECT [schema_name]
                FROM [mgmt_xtinfra].[infra_static_core_schemas]
                UNION
                SELECT CONCAT([ws].[workspace_name], '_', [se].[schema_name]) AS [schema_name]
                FROM [mgmt_xtinfra].[infra_static_ext_schemas] AS [se]
                CROSS JOIN [mgmt_xtinfra].[infra_workspace_identity_config] AS [ws]
                WHERE [ws].[workspace_type] = 'extension'
            ) AS [t]

        -- Check schema creation
        SELECT [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS [schema_name]
        INTO [#CreatedStaticSchemas]
        FROM [sys].[schemas]
        WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN (SELECT [schema_name] FROM [#StaticSchemas])

        PRINT (
            'The difference between created and expected Schemas for Static Schemas are given below. _m_ column denotes whether the expected Schema is missing (<), unexpected Schema creation (>) or correct assignment (=)'
        )
        EXEC [tSQLt_synapse].[AssertEqualsTable] '#StaticSchemas', '#CreatedStaticSchemas';
    END
END;
GO

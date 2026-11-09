BEGIN
    DECLARE @staticCoreSchemaNames varchar(4000)= N'[
                "core_bdv",
                "core_cl_reporting",
                "core_cla_outbound_interfaces",
                "core_dq",
                "core_etl_bdv",
                "core_etl_cl",
                "core_etl_rdv",
                "core_ext001_harmonized",
                "core_external_curated",
                "core_external_workspace",
                "core_rdm",
                "core_rdv",
                "core_technical_framework",
                "core_test_automation"
                ]' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8;

    DECLARE @staticExtensionSchemaNames varchar(4000)= N'[
                "etl_rdv",
                "rdm",
                "dq",
                "rdv",
                "etl_bdv",
                "bdv",
                "etl_cl",
                "cl_reporting",
                "cla_outbound_interfaces",
                "harmonized",
                "technical_framework",
                "external_curated",
                "external_workspace",
                "test_automation"
                ]' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8;

    -- STATIC CORE SCHEMAS
    TRUNCATE TABLE [mgmt_xtinfra].[infra_static_core_schemas]

    INSERT INTO [mgmt_xtinfra].[infra_static_core_schemas]
    SELECT [schema_name]
    FROM OPENJSON (@staticCoreSchemaNames) WITH ([schema_name] nvarchar(128) '$')

    -- STATIC EXT SCHEMAS
    TRUNCATE TABLE [mgmt_xtinfra].[infra_static_ext_schemas]

    INSERT INTO [mgmt_xtinfra].[infra_static_ext_schemas]
    SELECT [schema_name]
    FROM OPENJSON (@staticExtensionSchemaNames) WITH ([schema_name] nvarchar(128) '$')
END

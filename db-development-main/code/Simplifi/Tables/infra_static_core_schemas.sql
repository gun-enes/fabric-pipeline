CREATE TABLE [mgmt_xtinfra].[infra_static_core_schemas]
(
    [schema_name] [NVARCHAR](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL
)
WITH (DISTRIBUTION = REPLICATE);
GO

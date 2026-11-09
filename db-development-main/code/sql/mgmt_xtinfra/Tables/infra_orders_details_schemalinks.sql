CREATE TABLE [mgmt_xtinfra].[infra_orders_details_schemalinks]
(
    order_id [uniqueidentifier] NOT NULL,
	source_schema_name [nvarchar](42) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	source_schema_role_name [nvarchar](48) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	destination_schema_name [nvarchar](42) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	destination_schema_role_name [nvarchar](48) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL
)  WITH ( DISTRIBUTION = ROUND_ROBIN );
GO

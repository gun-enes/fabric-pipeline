CREATE TABLE [mgmt_xtinfra].[infra_stats_skip_details]
(
	[SchemaName] [sysname] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[TableName] [sysname] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[ConstraintName] [sysname] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	[ConstraintColumnName] [sysname] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[ConstraintColumnOrder] [tinyint] NOT NULL,
	[ColumnstoreIndexColumnName] [sysname] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	[ColumnstoreIndexColumnOrder] [int] NOT NULL
)
WITH
(
	DISTRIBUTION = REPLICATE,
	CLUSTERED COLUMNSTORE INDEX
)
GO

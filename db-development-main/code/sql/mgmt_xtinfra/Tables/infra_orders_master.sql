CREATE TABLE [mgmt_xtinfra].[infra_orders_master]
(
    id [uniqueidentifier] NOT NULL,
	order_date [datetime] NOT NULL,
	requestor [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	mode [nvarchar](32) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	type [nvarchar](32) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
	status [nvarchar](32) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL
) WITH ( DISTRIBUTION = ROUND_ROBIN, CLUSTERED INDEX([id]) );
GO

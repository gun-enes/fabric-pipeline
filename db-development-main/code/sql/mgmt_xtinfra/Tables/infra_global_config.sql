CREATE TABLE [mgmt_xtinfra].[infra_global_config]
(
    [key] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [value] [nvarchar](MAX) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
    [created_at] [datetime] NOT NULL,
    [updated_at] [datetime] NOT NULL
)
WITH (DISTRIBUTION = REPLICATE, CLUSTERED INDEX ([key]));

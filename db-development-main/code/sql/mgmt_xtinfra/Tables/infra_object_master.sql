CREATE TABLE [mgmt_xtinfra].[infra_object_master]
    (
        [type] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [name] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [version] [int]
    )
    WITH ( DISTRIBUTION = ROUND_ROBIN, CLUSTERED INDEX([type], [name]) );
GO

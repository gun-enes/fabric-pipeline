CREATE TABLE [mgmt_xtinfra].[infra_ext_decom_log]
(
    [LogID] [int] NULL,
    [ObjectType] [NVARCHAR](150) NULL,
    [SchemaName] [NVARCHAR](50) NULL,
    [ObjectName] [NVARCHAR](200) NULL,
    [Info] [NVARCHAR](150) NULL,
    [Timestamp] [datetime] NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
)
GO

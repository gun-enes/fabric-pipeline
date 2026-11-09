CREATE TABLE [mgmt_xtinfra].[infra_job_master_v2_details]
(
    [job_id] [uniqueidentifier] NOT NULL,
    [key] [nvarchar](128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    [value] [nvarchar](MAX) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL
)
WITH ( DISTRIBUTION = ROUND_ROBIN, CLUSTERED INDEX([job_id], [key]) );

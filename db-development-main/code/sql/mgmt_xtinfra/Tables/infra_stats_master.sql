CREATE TABLE [mgmt_xtinfra].[infra_stats_master] (
	execid int NULL,
	session_id int NULL,
	scriptversionid varchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	dbname varchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	job_desc varchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	status varchar(50) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	job_start_time datetime NULL,
    job_end_time datetime NULL,
	exec_user varchar(1000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL,
	workspace_name nvarchar(120) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
	app_name nvarchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
);
GO

CREATE TABLE mgmt_xtinfra.infra_script_master
(
  script_id int,
  db_name varchar(1000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  scriptversionid varchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  script_status varchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  created Datetime,
  workspace_name nvarchar(120) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  app_name nvarchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
);
GO

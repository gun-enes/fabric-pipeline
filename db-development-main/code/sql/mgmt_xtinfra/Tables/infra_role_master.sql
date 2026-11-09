CREATE TABLE mgmt_xtinfra.infra_role_master
(
  role_id int,
  role_name varchar(500) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  role_type varchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  dbname varchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  schema_id varchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  created Datetime,
  workspace_name nvarchar(120) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  app_name nvarchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
);
GO

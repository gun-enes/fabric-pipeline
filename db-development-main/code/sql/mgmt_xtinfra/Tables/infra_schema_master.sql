CREATE TABLE [mgmt_xtinfra].[infra_schema_master]
(
  schema_id int,
  schema_name varchar(1000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  schema_type varchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  dbname varchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  created Datetime,
  workspace_name nvarchar(120) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
  app_name nvarchar(100) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8
);
GO

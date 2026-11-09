CREATE PROCEDURE mgmt_xtinfra.sp_infra_login_sync_role
  /* Scope   : sync schema reader,writer,deployer,generic roles for login user
 * Project   : Simplfi
 * Activity  : Dedicated SQL pool deployment
 * Author    : jyothish.b@allianz.com
 */
  (
    @schema_name varchar(100),
    @login_user varchar(500),
    @role_type varchar(100),
    @workSpace nvarchar(120) ,
    @appName as nvarchar(100)
  ) AS
BEGIN
  DECLARE @cmd varchar(1000)
  DECLARE @ROLE_READER varchar(1000)
  DECLARE @ROLE_WRITER varchar(1000)
  DECLARE @ROLE_GENERIC varchar(1000)
  DECLARE @SCHEMA_DEPLOYER varchar(1000)
  DECLARE @output varchar(1000) = 'TEST'
  DECLARE @job_desc varchar(1000) = 'Login user role sync activity'
  DECLARE @proc_name varchar(100) = 'sp_infra_login_sync_role';
  DECLARE @log_detail_group uniqueidentifier = NEWID();

  BEGIN TRY
    --- add log entry for our job
	  EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'schema_name', @schema_name
	  EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'login_user', @login_user
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'role_type', @role_type
	  EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'workSpace', @workSpace
    EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'appName', @appName

    -- Only the dbo user may grant roles via this procedure.
    IF USER_NAME() <> 'dbo'
    BEGIN
        RAISERROR ('Caller is not authorised to execute role sync operations.', 16, 1);
    END

    IF (@schema_name IS NOT NULL AND @login_user IS NOT NULL AND @role_type IS NOT NULL)
    BEGIN
    IF EXISTS (select 1 from sys.database_principals where type_desc in  ('EXTERNAL_GROUP','EXTERNAL_USER') and name = @login_user)
    BEGIN
      SET @job_desc = 'Login user role sync for the schema ' + @schema_name
      EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'job_desc', @job_desc
      IF (@role_type = 'writer')
      BEGIN
        -- SET @ROLE_READER = + @schema_name + N'-schema-reader'
        SET @ROLE_WRITER = + @schema_name + N'-schema-writer'
        -- SET @ROLE_WRITER = + @schema_name + N'-schema-writer'
        SET @cmd = 'EXEC sp_addrolemember [' + @ROLE_WRITER + '],[' + @login_user + ']'
        EXEC (@cmd);
        SET @output = N'Role ' + @ROLE_WRITER + ' has been granted to login user ' + @login_user
        PRINT (@output);
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'out_msg', @output
      END --END for 'writer'
      ELSE IF (@role_type = 'reader')
      BEGIN
        SET @ROLE_READER = + @schema_name + N'-schema-reader'
        SET @cmd = 'if exists (select 1 from sys.database_principals where name=''' + @ROLE_READER + ''' and Type = ''R'') EXEC sp_addrolemember [' + @ROLE_READER + '],[' + @login_user + '] ;'
        EXEC (@cmd);
        SET @output = N'Role ' + @ROLE_READER + ' has been granted to login user ' + @login_user
        PRINT (@output);
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'out_msg', @output
      END --END for 'reader'
      ELSE IF (@role_type = 'generic')
      BEGIN
        SET @ROLE_GENERIC = + @schema_name + N''
        SET @cmd = 'EXEC sp_addrolemember [' + @ROLE_GENERIC + '],[' + @login_user + ']'
        EXEC (@cmd);
        SET @output = N'Role ' + @ROLE_GENERIC + ' has been granted to login user ' + @login_user
        PRINT (@output);
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'out_msg', @output
      END --END for 'generic'
      ELSE IF (@role_type = 'schema_deployer') -- ELSE IF for schema_deployer
      BEGIN
        SET @SCHEMA_DEPLOYER = + @schema_name + N'-schema-deployer'
        IF NOT EXISTS (select 1 from sys.database_principals where type_desc in  ('DATABASE_ROLE') and name = @SCHEMA_DEPLOYER) -- Role exists check
        BEGIN
          SET @job_desc = 'Manual schema deployor Role creation'
          SET @cmd = N'CREATE ROLE [' + @SCHEMA_DEPLOYER + ']'
          EXEC (@cmd);
          SET @output = N'Role ' + @SCHEMA_DEPLOYER + ' has been created'
          PRINT (@output);
          EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'out_msg', @output
          SET @cmd = N'GRANT ALTER,CONTROL ON SCHEMA::[' + @schema_name + '] TO [' + @SCHEMA_DEPLOYER + ']'
          EXEC (@cmd);
          SET @cmd = 'EXEC sp_addrolemember [' + @SCHEMA_DEPLOYER + '],[' + @login_user + ']'
          EXEC (@cmd);
          SET @output = N'Role ' + @SCHEMA_DEPLOYER + ' has been granted to login user ' + @login_user
          PRINT (@output);
          EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'out_msg', @output
        END --END for 'Role exists check'
        ELSE
        BEGIN
          SET @cmd = 'EXEC sp_addrolemember [' + @SCHEMA_DEPLOYER + '],[' + @login_user + ']'
          EXEC (@cmd);
          SET @output = N'Role ' + @SCHEMA_DEPLOYER + ' is already exists but role has been granted to login user ' + @login_user
          PRINT (@output);
          EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'out_msg', @output
        END
      END -- END for schema_deployer
      EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'success';
    END -- END FOR IF database_principals EXTERNAL GROUP
    ELSE
    BEGIN
        SET @job_desc = 'Login user role sync for the schema ' + @schema_name
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'job_desc', @job_desc
        SET @output = N'Roles has not been granted due to unavailability of login user  ' + @login_user
        PRINT (@output);
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'out_msg', @output
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'failure';
      END -- END FOR ELSE database_principals EXTERNAL GROUP
    END --END FOR IF  @schema_name IS NOT NULL AND @login_user IS NOT NULL AND @role_type IS NOT NULL
    ELSE
    BEGIN
      SET @output =  'Incorrect syntax for the procedure mgmt_xtinfra.sp_infra_login_sync_role'
      PRINT (@output);
      EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'out_msg', @output
      EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'failure';
    END
  END TRY
  BEGIN CATCH
    DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
		DECLARE @error_severity INT = ERROR_SEVERITY();
		DECLARE @error_state INT = ERROR_STATE();
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_message', @error_message
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_severity', @error_severity
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'error_state', @error_state
		EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'failure';
		--- then throw again to forward error
		THROW;
  END CATCH
END

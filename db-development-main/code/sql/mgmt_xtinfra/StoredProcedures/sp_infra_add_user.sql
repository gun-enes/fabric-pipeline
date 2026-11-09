CREATE PROC mgmt_xtinfra.sp_infra_add_user @login_user [varchar](500), @workSpace nvarchar(120) , @appName as nvarchar(100) AS
/* Scope    : CREATE USER @login_user from EXTERNAL PROVIDER with Exceptions handling and logging information to mgmt_xtinfra.infra_job_master_v2
 * Project  : Simplfi
 * Activity : Dedicated SQL pool deployment
 * Author   : extern.karolczak_michal@allianz.com
 */
BEGIN
  DECLARE @cmd nvarchar(MAX)
  DECLARE @output nvarchar(1000) = 'TEST'
  DECLARE @job_desc nvarchar(MAX)
  DECLARE @proc_name nvarchar(128) = 'sp_infra_add_user';
  DECLARE @log_detail_group uniqueidentifier = NEWID();

  BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    IF (@login_user IS NOT NULL )
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @login_user)
         BEGIN
          EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'login_user', @login_user;
          EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'workSpace', @workSpace;
          EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'appName', @appName;
          PRINT('Creating New Database Principal '+ @login_user + ' for workspace: ' + @workSpace + ' from app: ' + @appName);
          SET @job_desc = 'Creating user: ' + @login_user + ' for workspace: ' + @workSpace + ' from app: ' + @appName
          SET @cmd = 'CREATE USER '+QUOTENAME(@login_user)+' FROM EXTERNAL PROVIDER'
          EXEC (@cmd);
          SET @output = N'USER ' + @login_user + ' created'
          EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @output;
          EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';
         END
        ELSE
         BEGIN
          SET @output = 'User: ' + @login_user + ' already exists';
          EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @output;
          EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';
         END
      END
    ELSE
      BEGIN
        SET @output = 'NULL Value provided for User';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @output;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'failure';
      END
  END TRY
  BEGIN CATCH
    SELECT @output = ERROR_MESSAGE() ;
      print 'Error adding user !!!'
    DECLARE @error_severity int = ERROR_SEVERITY();
    DECLARE @error_state int = ERROR_STATE();
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'error_message', @output;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'error_severity', @error_severity;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'error_state', @error_state;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'failure';
  END CATCH
END

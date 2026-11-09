CREATE PROC [mgmt_xtinfra].[sp_infra_appl_usr_handler] AS
BEGIN
    declare @sid [int];
    declare @cr [datetime];
	declare @us [varchar](100);
	declare @rq [varchar](100);
	declare @op [varchar](100);
	declare @pc [datetime];
	declare @rs [varchar](100);
    declare @now [datetime] = sysdatetime();
    declare @cmd [varchar](200);
    declare @out [varchar](200);
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @proc_name nvarchar(128) = 'sp_infra_appl_usr_handler';
    DECLARE @RowCount INT = (SELECT COUNT(*) FROM [mgmt_xtinfra].[infra_appl_usr_master] where [processed] IS NULL);
   BEGIN TRY
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
    select top 1
         @sid=[sid]
        ,@cr=[created]
        ,@us=[user]
        ,@rq=[requestor]
        ,@op=[action]
        ,@pc=[processed]
        ,@rs=[result]
    from  [mgmt_xtinfra].[infra_appl_usr_master] where [processed] IS NULL ORDER BY [sid];
    WHILE @sid is not NULL and ( @RowCount>0 )
    BEGIN
        exec [mgmt_xtinfra].sp_infra_user_handler @us, @op, @out OUTPUT
        set @now = sysdatetime();
        update [mgmt_xtinfra].[infra_appl_usr_master] set [processed]=@now,[result]=@out where [sid]=@sid
            select top 1
                   @sid=[sid]
                  ,@cr=[created]
                  ,@us=[user]
                  ,@rq=[requestor]
                  ,@op=[action]
                  ,@pc=[processed]
                  ,@rs=[result]
            from  [mgmt_xtinfra].[infra_appl_usr_master] where [processed] IS NULL and [sid]>@sid ORDER BY [sid];
        SET @RowCount -= 1;
    END;
    EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';
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
END;

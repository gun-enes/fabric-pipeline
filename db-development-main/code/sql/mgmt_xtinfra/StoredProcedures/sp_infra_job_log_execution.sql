/*
Description:
This stored procedure is used to log the execution of a job. It should be called at the end of a job execution
to log the status of the job and any additional details that might be useful for debugging or monitoring purposes.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_job_log_execution]
(
    @job_id uniqueidentifier,
    @job_name nvarchar(128),
    @job_status varchar(16)
)
AS
BEGIN
	--- VALIDATE INPUTS

	--- @job_status needs to match a set of allowed values
	IF @job_status NOT IN ('success', 'failure', 'warning','started')
	BEGIN
		THROW 50000, '@job_status needs to be success, failure, started or warning', 1
	END

    DECLARE @date DateTime = GETDATE()
	DECLARE @session_id [int] = @@SPID
    DECLARE @session_user [nvarchar](128) = SESSION_USER
    DECLARE @id uniqueidentifier = NEWID()

    INSERT INTO [mgmt_xtinfra].[infra_job_master_v2] (id, date, name, status, [session_id], [session_user])
    VALUES (@job_id, @date, @job_name, @job_status, @session_id, @session_user)
END

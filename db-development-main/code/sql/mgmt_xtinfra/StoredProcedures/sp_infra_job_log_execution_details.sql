/*
Description:
This stored procedure is used to log the execution of a job. It should be called at the end of a job execution
to log the status of the job and any additional details that might be useful for debugging or monitoring purposes.

Author:
extern.nachtrub_daniel@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_job_log_execution_details]
(
    @job_log_detail_group uniqueidentifier,
    @key nvarchar(128),
    @value nvarchar(MAX)
)
AS
BEGIN
    INSERT INTO [mgmt_xtinfra].[infra_job_master_v2_details] (job_id, [key], [value])
    VALUES (@job_log_detail_group, @key, @value)
END

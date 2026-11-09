CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_upsert_global_config]
    @key [nvarchar](128),
    @value [nvarchar](4000)
AS
BEGIN
	DECLARE @proc_name nvarchar(128) = 'sp_infra_upsert_global_config';
	DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @now datetime = GETDATE();

    BEGIN TRY
        --log details
        -- directly giving a variable named @key as the @value parameter of the logging sp causes an error
        DECLARE @schedule_key [nvarchar](100) = @key
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'key', @schedule_key
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'value', @value

        IF EXISTS (
            SELECT 1
            FROM [mgmt_xtinfra].[infra_global_config]
            WHERE [key] = @key
        )
        BEGIN
            PRINT 'Key already exists in global_config, updating value'
            UPDATE [mgmt_xtinfra].[infra_global_config]
            SET [value] = @value, [updated_at] = @now
            WHERE [key] = @key;
        END
        ELSE
        BEGIN
            PRINT 'Key does not exist in global_config, creating new entry'
            INSERT INTO [mgmt_xtinfra].[infra_global_config]
            ([key], [value], [created_at], [updated_at])
            VALUES (@key, @value, @now, @now);
        END

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';

    END TRY
    BEGIN CATCH
        --- add log entry for our job
        DECLARE @error_message nvarchar(4000) = ERROR_MESSAGE();
        DECLARE @error_severity int = ERROR_SEVERITY();
        DECLARE @error_state int = ERROR_STATE();

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'error_message', @error_message;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'error_severity', @error_severity;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'error_state', @error_state;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'failure';
        --- then throw again to forward error
        THROW;
    END CATCH
END

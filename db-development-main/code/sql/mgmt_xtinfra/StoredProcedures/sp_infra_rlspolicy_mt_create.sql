/*
Description:
Creates an RLS policy with given specifications.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_rlspolicy_mt_create]
    @schema_name [nvarchar](42),
    @policy_name [nvarchar](128),
    @predicate_function_name [nvarchar](128),
    @table_name [nvarchar](78),
    @parameter_list [nvarchar](4000)
AS
BEGIN
    --- define required variables
    DECLARE @proc_name nvarchar(128) = 'sp_infra_rlspolicy_mt_create';
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(512);
    DECLARE @param_string nvarchar(128);

    BEGIN TRY
    --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'schema_name', @schema_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'policy_name', @policy_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'predicate_function_name', @predicate_function_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'table_name', @table_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'parameter_list', @parameter_list;

        PRINT 'Executing rlspolicy path. mode: upgrade'
        + ', schema_name: '
        + @schema_name
        + ', policy_name: '
        + @policy_name
        + ', predicate_function_name: '
        + @predicate_function_name
        + ', table_name: '
        + @table_name
        + ', parameter_list: '
        + @parameter_list;

        SELECT @param_string = STRING_AGG(CAST(QUOTENAME([value]) AS NVARCHAR(MAX)), ',')
        FROM OPENJSON(@parameter_list)
        SET
            @sql_stmt
            = N'CREATE SECURITY POLICY '
            + QUOTENAME(@schema_name)
            + '.'
            + QUOTENAME(@policy_name)
            + ' ADD FILTER PREDICATE '
            + QUOTENAME(@schema_name)
            + '.'
            + QUOTENAME(@predicate_function_name)
            + '('
            + @param_string
            + ') ON '
            + QUOTENAME(@schema_name)
            + '.'
            + QUOTENAME(@table_name)
            + ';';

        IF
            NOT EXISTS (
                SELECT 1
                FROM [sys].[security_policies] AS [sp]
                INNER JOIN
                    [sys].[schemas] AS [schemas]
                    ON ([sp].[schema_id] = [schemas].[schema_id])
                WHERE
                    [sp].[name] = @policy_name
                    AND [schemas].[name] = @schema_name
            )
            BEGIN
                PRINT 'Creating security policy: ' + @policy_name;
                EXEC [sp_executesql] @sql_stmt;
            END

        --- add log entry for our job
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'success';
    END TRY
    BEGIN CATCH
        --- add log entry for our job
        DECLARE @error_message nvarchar(4000) = ERROR_MESSAGE();
        DECLARE @error_severity int = ERROR_SEVERITY();
        DECLARE @error_state int = ERROR_STATE();

        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_message', @error_message;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_severity', @error_severity;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'error_state', @error_state;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'failure';

        --- then throw again to forward error
        THROW;
    END CATCH
END
GO

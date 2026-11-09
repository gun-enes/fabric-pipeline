/*
Description:
This stored procedure is used to create or delete Workload Group based on the parameters.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workloadgroup_migrationtask_0001]
    (
        @mode [nvarchar](32),
        @group_name [nvarchar](128),
        @min_percentage_resource [int],
        @cap_percentage_resource [int],
        @request_min_resource_grant_percent [decimal](5, 2),
        @request_max_resource_grant_percent [decimal](5, 2),
        @importance [nvarchar](128),
        @query_execution_timeout_sec [int]
    )
AS
BEGIN

    --- use this to easily assign the migration task id for this task
    DECLARE @version_object_type nvarchar(128) = 'workloadgroup';
    DECLARE @version_object_name nvarchar(128) = @group_name;
    DECLARE @proc_name nvarchar(128) = 'sp_infra_workloadgroup_migrationtask_0001';

    --- define required variables
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @sql_stmt nvarchar(512);

    BEGIN TRY

        --- assign logging details already here
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'mode', @mode;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'group_name', @group_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'min_percentage_resource', @min_percentage_resource;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'cap_percentage_resource', @cap_percentage_resource;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'request_min_resource_grant_percent', @request_min_resource_grant_percent;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'request_max_resource_grant_percent', @request_max_resource_grant_percent;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'importance', @importance;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'query_execution_timeout_sec', @query_execution_timeout_sec;

        --- calc target version
        -- on downgrades we will set the target version to the previous version
        DECLARE @migrationtask_id int = [mgmt_xtinfra].InfraGetMigrationTaskId(@proc_name);
        DECLARE @version_object_version int = @migrationtask_id;
        IF @mode = 'downgrade'
            SET @version_object_version = @migrationtask_id - 1;
        --- validate if we are in the correct version range to apply our change
        DECLARE @can_migrate bit = 0;
        EXEC [mgmt_xtinfra].[sp_infra_get_migrationtask_canmigrate_object]
            @version_object_type, @version_object_name, @mode, @migrationtask_id, @can_migrate OUTPUT;

        IF @can_migrate = 1
            BEGIN
                IF @mode = 'upgrade'
                    BEGIN
                        IF
                            EXISTS (
                                SELECT 1
                                FROM [sys].[workload_management_workload_groups]
                                WHERE
                                    [name] = @group_name
                            )
                            SET @sql_stmt = N'ALTER WORKLOAD GROUP ';
                        ELSE
                            SET @sql_stmt = N'CREATE WORKLOAD GROUP ';

                        SET
                            @sql_stmt
                            = @sql_stmt
                            + @group_name
                            + ' WITH ( MIN_PERCENTAGE_RESOURCE = '
                            + CAST(@min_percentage_resource AS nvarchar(10))
                            + ',CAP_PERCENTAGE_RESOURCE = '
                            + CAST(@cap_percentage_resource AS nvarchar(10))
                            + ',REQUEST_MIN_RESOURCE_GRANT_PERCENT = '
                            + CAST(@request_min_resource_grant_percent AS nvarchar(10))

                        IF @request_max_resource_grant_percent IS NOT NULL
                            SET
                                @sql_stmt = @sql_stmt
                                + ',REQUEST_MAX_RESOURCE_GRANT_PERCENT = '
                                + CAST(@request_max_resource_grant_percent AS nvarchar(10));

                        IF @importance IS NOT NULL
                            SET
                                @sql_stmt = @sql_stmt
                                + ',IMPORTANCE = '
                                + @importance;

                        IF @query_execution_timeout_sec IS NOT NULL
                            SET
                                @sql_stmt = @sql_stmt
                                + ',QUERY_EXECUTION_TIMEOUT_SEC = '
                                + CAST(@query_execution_timeout_sec AS nvarchar(10));

                        SET @sql_stmt = @sql_stmt + ')';
                        EXEC (@sql_stmt);
                    END
                ELSE IF @mode = 'downgrade'
                    BEGIN
                        PRINT 'Running migration in downgrade mode: ' + @proc_name;
                        IF
                            EXISTS (
                                SELECT 1
                                FROM [sys].[workload_management_workload_groups]
                                WHERE
                                    [name] = @group_name
                            )
                            BEGIN
                                PRINT 'Deleting workload group: ' + @group_name
                                SET @sql_stmt = 'DROP WORKLOAD GROUP ' + QUOTENAME(@group_name);
                                EXEC (@sql_stmt);
                            END
                    END
                ELSE IF @mode = 'validate'
                    BEGIN
                        PRINT 'Running migration in validate mode: ' + @proc_name;
                        IF
                            NOT EXISTS (
                                SELECT 1
                                FROM [sys].[workload_management_workload_groups]
                                WHERE
                                    [name] = @group_name
                            )
                            THROW 50000, 'Validation failed. Workload group does not exist.', 1;
                    END
                ELSE
                    THROW 50000, 'Invalid mode specified for migration task.', 1;

                --- persist object version
                EXEC [mgmt_xtinfra].[sp_infra_set_object_version]
                    @version_object_type, @version_object_name, @version_object_version;
                --- add log entry for our job
                EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'success';
            END
        ELSE
            BEGIN
                IF @mode = 'upgrade'
                    BEGIN
                        PRINT 'Running migration in upgrade (alter) mode: ' + @proc_name;
                        IF
                            EXISTS (
                                SELECT 1
                                FROM [sys].[workload_management_workload_groups]
                                WHERE
                                    [name] = @group_name
                            )
                            BEGIN
                                SET
                                    @sql_stmt
                                    = N'ALTER WORKLOAD GROUP '
                                    + @group_name
                                    + ' WITH ( MIN_PERCENTAGE_RESOURCE = '
                                    + CAST(@min_percentage_resource AS nvarchar(10))
                                    + ',CAP_PERCENTAGE_RESOURCE = '
                                    + CAST(@cap_percentage_resource AS nvarchar(10))
                                    + ',REQUEST_MIN_RESOURCE_GRANT_PERCENT = '
                                    + CAST(@request_min_resource_grant_percent AS nvarchar(10));

                                IF @request_max_resource_grant_percent IS NOT NULL
                                    SET
                                        @sql_stmt = @sql_stmt
                                        + ',REQUEST_MAX_RESOURCE_GRANT_PERCENT = '
                                        + CAST(@request_max_resource_grant_percent AS nvarchar(10));

                                IF @importance IS NOT NULL
                                    SET
                                        @sql_stmt = @sql_stmt
                                        + ',IMPORTANCE = '
                                        + @importance;

                                IF @query_execution_timeout_sec IS NOT NULL
                                    SET
                                        @sql_stmt = @sql_stmt
                                        + ',QUERY_EXECUTION_TIMEOUT_SEC = '
                                        + CAST(@query_execution_timeout_sec AS nvarchar(10));

                                SET @sql_stmt = @sql_stmt + ')';
                                EXEC (@sql_stmt);
                            END
                    END
            END
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

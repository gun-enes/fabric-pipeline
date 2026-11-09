/*
Description:
Creates or updates a workload classifier.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_workload_classifier_create_or_update] (
    @classifier_name NVARCHAR(128),
    @wg_name NVARCHAR(128),
    @member_name NVARCHAR(128),
    @wlm_label NVARCHAR(255),
    @wlm_context NVARCHAR(255),
    @start_time NVARCHAR(5),
    @end_time NVARCHAR(5),
    @importance NVARCHAR(128)
)
AS
BEGIN
    DECLARE @requestor NVARCHAR(128) = SESSION_USER;
    DECLARE @order_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @proc_name NVARCHAR(128) = 'sp_infra_workload_classifier_create_or_update';
    DECLARE @log_detail_group UNIQUEIDENTIFIER = NEWID();
    DECLARE @cmd NVARCHAR(2000);

    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'classifier_name', @order_id;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'wg_name', @wg_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'member_name', @member_name;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'wlm_label', @wlm_label;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'wlm_context', @wlm_context;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'start_time', @start_time;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'end_time', @end_time;
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details]
            @log_detail_group, 'importance', @importance;

        IF
            NOT EXISTS (
                SELECT 1 FROM [sys].[workload_management_workload_classifiers] WHERE [name] = @classifier_name
            )
            BEGIN
                PRINT 'Workload classifier ' + @classifier_name + ' does not exist, creating it..'
                SET
                    @cmd
                    = N'CREATE WORKLOAD CLASSIFIER '
                    + QUOTENAME(@classifier_name)
                    + ' WITH ( WORKLOAD_GROUP = '''
                    + @wg_name
                    + ''',MEMBERNAME = '''
                    + @member_name;

                IF @wlm_label IS NOT NULL
                    SET
                        @cmd = @cmd
                        + ''',WLM_LABEL = '''
                        + @wlm_label;

                IF @wlm_context IS NOT NULL
                    SET
                        @cmd = @cmd
                        + ''',WLM_CONTEXT = '''
                        + @wlm_context;

                IF @start_time IS NOT NULL
                    SET
                        @cmd = @cmd
                        + ''',START_TIME = '''
                        + @start_time;

                IF @end_time IS NOT NULL
                    SET
                        @cmd = @cmd
                        + ''',END_TIME = '''
                        + @end_time;

                IF @importance IS NOT NULL
                    SET
                        @cmd = @cmd
                        + '''  ,IMPORTANCE = '
                        + @importance;

                SET @cmd = @cmd + ')';
                EXEC (@cmd);
            END
        ELSE
            -- There is no ALTER command for workload classifiers
            -- So we need to drop and re-create the classifier to achieve the same effect.
            -- But we do not want to affect anyone already using the classifier during this process.
            -- So we create a temp classifier with the same configuration before dropping and re-creating the old one.
            BEGIN
                PRINT 'Workload classifier ' + @classifier_name + ' exists, dropping and re-creating it..'
                DECLARE @temp_classifier_name NVARCHAR(128) = @classifier_name + '_temp';
                IF
                    NOT EXISTS (
                        SELECT 1
                        FROM [sys].[workload_management_workload_classifiers]
                        WHERE [name] = @temp_classifier_name
                    )
                    BEGIN
                        -- Create temp classifier
                        SET
                            @cmd
                            = N'CREATE WORKLOAD CLASSIFIER '
                            + QUOTENAME(@temp_classifier_name)
                            + ' WITH ( WORKLOAD_GROUP = '''
                            + @wg_name
                            + ''',MEMBERNAME = '''
                            + @member_name;

                        IF @wlm_label IS NOT NULL
                            SET
                                @cmd = @cmd
                                + ''',WLM_LABEL = '''
                                + @wlm_label;

                        IF @wlm_context IS NOT NULL
                            SET
                                @cmd = @cmd
                                + ''',WLM_CONTEXT = '''
                                + @wlm_context;

                        IF @start_time IS NOT NULL
                            SET
                                @cmd = @cmd
                                + ''',START_TIME = '''
                                + @start_time;

                        IF @end_time IS NOT NULL
                            SET
                                @cmd = @cmd
                                + ''',END_TIME = '''
                                + @end_time;

                        IF @importance IS NOT NULL
                            SET
                                @cmd = @cmd
                                + '''  ,IMPORTANCE = '
                                + @importance;

                        SET @cmd = @cmd + ')';
                        EXEC (@cmd);
                    END
                -- Drop old classifier
                SET @cmd = 'DROP WORKLOAD CLASSIFIER ' + QUOTENAME(@classifier_name);
                EXEC (@cmd);

                -- Re-create classifier
                SET
                    @cmd
                    = N'CREATE WORKLOAD CLASSIFIER '
                    + QUOTENAME(@classifier_name)
                    + ' WITH ( WORKLOAD_GROUP = '''
                    + @wg_name
                    + ''',MEMBERNAME = '''
                    + @member_name;

                IF @wlm_label IS NOT NULL
                    SET
                        @cmd = @cmd
                        + ''',WLM_LABEL = '''
                        + @wlm_label;

                IF @wlm_context IS NOT NULL
                    SET
                        @cmd = @cmd
                        + ''',WLM_CONTEXT = '''
                        + @wlm_context;

                IF @start_time IS NOT NULL
                    SET
                        @cmd = @cmd
                        + ''',START_TIME = '''
                        + @start_time;

                IF @end_time IS NOT NULL
                    SET
                        @cmd = @cmd
                        + ''',END_TIME = '''
                        + @end_time;

                IF @importance IS NOT NULL
                    SET
                        @cmd = @cmd
                        + '''  ,IMPORTANCE = '
                        + @importance;

                SET @cmd = @cmd + ')';
                EXEC (@cmd);

                -- Drop temp classifier
                SET @cmd = 'DROP WORKLOAD CLASSIFIER ' + QUOTENAME(@temp_classifier_name);
                EXEC (@cmd);
            END
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution]
            @log_detail_group, @proc_name, 'success';
    END TRY
    BEGIN CATCH
        --- add log entry for our job
        DECLARE @error_message NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @error_severity INT = ERROR_SEVERITY();
        DECLARE @error_state INT = ERROR_STATE();

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

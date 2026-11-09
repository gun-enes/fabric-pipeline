/*
Description:
Updates self-service objects according to their most recent orders.

Author:
extern.guven_savas1@allianz.de
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_auto_update_ss_objects]
AS
BEGIN
    DECLARE @total_objects INT;
    DECLARE @current_count INT = 1;
    DECLARE @object_type NVARCHAR(128);
    DECLARE @object_name NVARCHAR(128);
    DECLARE @object_version INT;
    DECLARE @order_mode NVARCHAR(32);
    DECLARE @order_status NVARCHAR(32);
    DECLARE @msg NVARCHAR(MAX);
    DECLARE @object_attributes NVARCHAR(500);
    DECLARE @log_detail_group uniqueidentifier = NEWID();
    DECLARE @proc_name nvarchar(128) = 'sp_infra_auto_update_ss_objects';
  BEGIN TRY
    IF (OBJECT_ID('tempdb..#UpdateTable') IS NOT NULL)
        DROP TABLE #UpdateTable;

    CREATE TABLE #UpdateTable (
        [object_number] INT,
        [object_type] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [object_name] NVARCHAR(128) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
        [object_version] INT
    ) WITH (DISTRIBUTION = ROUND_ROBIN);

    INSERT INTO [#UpdateTable] ([object_number], [object_type], [object_name], [object_version])
    SELECT
        ROW_NUMBER() OVER (ORDER BY [name]),
        [type],
        [name],
        [version]
    FROM
        [mgmt_xtinfra].[infra_object_master]

    SELECT @total_objects = COUNT(*) FROM [#UpdateTable]

    WHILE (@current_count <= @total_objects)
        BEGIN
            SELECT
                @object_type = [object_type],
                @object_name = [object_name],
                @object_version = [object_version]
            FROM [#UpdateTable]
            WHERE [object_number] = @current_count;

            BEGIN TRY
                IF (@object_type = 'schema')
                    BEGIN
                        --default behaviour is to upgrade as SPF does not have schema orders for static schemas
                        SET @order_status = 'completed';
                        SET @order_mode = 'upgrade';

                        SELECT TOP (1)
                            @order_mode = [orders].[mode],
                            @order_status = [orders].[status]
                        FROM [mgmt_xtinfra].[infra_orders_details_schemas] AS [details]
                        INNER JOIN [mgmt_xtinfra].[infra_orders_master] AS [orders]
                            ON [details].[order_id] = [orders].[id]
                        WHERE
                            CONCAT([details].[workspace_name], '_', [details].[schema_name]) = @object_name
                        ORDER BY [orders].[order_date] DESC;

                        IF (@order_status = 'failed' OR @order_status = 'completed')
                            BEGIN
                                IF (@order_mode = 'upgrade')
                                    BEGIN
                                        UPDATE [mgmt_xtinfra].[infra_object_master]
                                        SET [version] = 0
                                        WHERE
                                            [name] = @object_name
                                            AND [type] = 'schema'
                                        SET @msg = (
                                            'Upgrading object with name: '
                                            + @object_name
                                            + ' and version: '
                                            + CAST(@object_version AS NVARCHAR(4))
                                        );
                                        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
                                        PRINT @msg;
                                        EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version]
                                            'upgrade', 0, 9999, @object_name;
                                    END
                                ELSE IF (@order_mode = 'downgrade')
                                    BEGIN
                                        UPDATE [mgmt_xtinfra].[infra_object_master]
                                        SET [version] = 4
                                        WHERE
                                            [name] = @object_name
                                            AND [type] = 'schema'

                                        SET @msg= (
                                            'Downgrading object with name: '
                                            + @object_name
                                            + ' and version: '
                                            + CAST(@object_version AS NVARCHAR(4))
                                        );
                                        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
                                        PRINT @msg;
                                        EXEC [mgmt_xtinfra].[sp_infra_schema_run_to_version]
                                            'downgrade', 9999, 0, @object_name;
                                    END
                            END
                    END
                ELSE IF (@object_type = 'schemarole')
                    BEGIN
                        --default behaviour is to upgrade as SPF does not have schemarole orders for static schemas
                        SET @order_status = 'completed';
                        SET @order_mode = 'upgrade';

                        -- generate parameters from object name in case of order does not exist especially for SPF
                        DECLARE
                            @role_name [NVARCHAR](48) = SUBSTRING(@object_name, CHARINDEX('-schema-', @object_name) + 8, LEN(@object_name));
                        DECLARE
                            @schema_part [NVARCHAR](43) = SUBSTRING(@object_name, 0, CHARINDEX('-schema-', @object_name));
                        SELECT TOP (1)
                            @order_mode = [orders].[mode],
                            @order_status = [orders].[status],
                            @role_name = [details].[role_name],
                            @schema_part = CONCAT([details].[workspace_name], '_', [details].[schema_name])
                        FROM [mgmt_xtinfra].[infra_orders_details_schemaroles] AS [details]
                        INNER JOIN [mgmt_xtinfra].[infra_orders_master] AS [orders]
                            ON [details].[order_id] = [orders].[id]
                        WHERE
                            CONCAT(
                                [details].[workspace_name],
                                '_',
                                [details].[schema_name],
                                '-schema-',
                                [details].[role_name]
                            )
                            = @object_name
                        ORDER BY [orders].[order_date] DESC;

                        IF (@order_status = 'failed' OR @order_status = 'completed')
                            BEGIN
                                IF (@order_mode = 'upgrade')
                                    BEGIN
                                        UPDATE [mgmt_xtinfra].[infra_object_master]
                                        SET [version] = 0
                                        WHERE
                                            [name] = @object_name
                                            AND [type] = 'schemarole'

                                        SET @msg= (
                                            'Upgrading object with name: '
                                            + @object_name
                                            + ' and version: '
                                            + CAST(@object_version AS NVARCHAR(4))
                                        );
                                        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
                                        PRINT @msg;
                                        EXEC [mgmt_xtinfra].[sp_infra_schemarole_run_to_version]
                                            'upgrade', 0, 9999, @schema_part, @role_name;
                                    END
                                ELSE IF (@order_mode = 'downgrade')
                                    BEGIN
                                        UPDATE [mgmt_xtinfra].[infra_object_master]
                                        SET [version] = 1
                                        WHERE
                                            [name] = @object_name
                                            AND [type] = 'schemarole'

                                        SET @msg= (
                                            'Downgrading object with name: '
                                            + @object_name
                                            + ' and version: '
                                            + CAST(@object_version AS NVARCHAR(4))
                                        );
                                        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
                                        PRINT @msg;
                                        EXEC [mgmt_xtinfra].[sp_infra_schemarole_run_to_version]
                                            'downgrade', 9999, 0, @schema_part, @role_name;
                                    END
                            END
                    END
                ELSE IF (@object_type = 'schemalink')
                    BEGIN
                        DECLARE @source_schema_name [NVARCHAR](42);
                        DECLARE @source_schema_role_name [NVARCHAR](48);
                        DECLARE @destination_schema_name [NVARCHAR](42);
                        DECLARE @destination_schema_role_name [NVARCHAR](48);
                        DECLARE
                            @source_part [NVARCHAR](98) = SUBSTRING(@object_name, 0, CHARINDEX('_to_', @object_name));
                        DECLARE
                            @destination_part [NVARCHAR](98) = SUBSTRING(@object_name, CHARINDEX('_to_', @object_name) + 4, LEN(@object_name));
                        SELECT TOP (1)
                            @order_mode = [orders].[mode],
                            @order_status = [orders].[status],
                            @source_schema_name = [details].[source_schema_name],
                            @source_schema_role_name = [details].[source_schema_role_name],
                            @destination_schema_name = [details].[destination_schema_name],
                            @destination_schema_role_name = [details].[destination_schema_role_name]
                        FROM [mgmt_xtinfra].[infra_orders_details_schemalinks] AS [details]
                        INNER JOIN [mgmt_xtinfra].[infra_orders_master] AS [orders]
                            ON [details].[order_id] = [orders].[id]
                        WHERE
                            CONCAT([details].[source_schema_name], '-schema-', [details].[source_schema_role_name])
                            = @source_part
                            AND CONCAT(
                                [details].[destination_schema_name],
                                '-schema-',
                                [details].[destination_schema_role_name]
                            )
                            = @destination_part
                        ORDER BY [orders].[order_date] DESC;

                        IF (@order_status = 'failed' OR @order_status = 'completed')
                            BEGIN
                                IF (@order_mode = 'upgrade')
                                    BEGIN
                                        UPDATE [mgmt_xtinfra].[infra_object_master]
                                        SET [version] = 0
                                        WHERE
                                            [name] = @object_name
                                            AND [type] = 'schemalink'

                                        SET @msg= (
                                            'Upgrading object with name: '
                                            + @object_name
                                            + ' and version: '
                                            + CAST(@object_version AS NVARCHAR(4))
                                        );
                                        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
                                        PRINT @msg;
                                        EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version]
                                            'upgrade', 0, 9999, @source_schema_name, @source_schema_role_name, @destination_schema_name, @destination_schema_role_name;
                                    END
                                ELSE IF (@order_mode = 'downgrade')
                                    BEGIN
                                        UPDATE [mgmt_xtinfra].[infra_object_master]
                                        SET [version] = 1
                                        WHERE
                                            [name] = @object_name
                                            AND [type] = 'schemalink'

                                        SET @msg= (
                                            'Downgrading object with name: '
                                            + @object_name
                                            + ' and version: '
                                            + CAST(@object_version AS NVARCHAR(4))
                                        );
                                        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
                                        PRINT @msg
                                        EXEC [mgmt_xtinfra].[sp_infra_schemalink_run_to_version]
                                            'downgrade', 9999, 0, @source_schema_name, @source_schema_role_name, @destination_schema_name, @destination_schema_role_name;
                                    END
                            END
                    END
                ELSE IF (@object_type = 'rlspolicy')
                    BEGIN
                        DECLARE @schema_name [NVARCHAR](128);
                        DECLARE @predicate_function_name [NVARCHAR](128);
                        DECLARE @table_name [NVARCHAR](78);
                        DECLARE @parameter_list [NVARCHAR](4000);

                        SELECT TOP (1)
                            @order_mode = [orders].[mode],
                            @order_status = [orders].[status],
                            @schema_name = [details].[schema_name],
                            @predicate_function_name = [details].[predicate_function_name],
                            @table_name = [details].[table_name],
                            @parameter_list = [details].[parameter_list]
                        FROM [mgmt_xtinfra].[infra_orders_details_rlspolicy] AS [details]
                        INNER JOIN [mgmt_xtinfra].[infra_orders_master] AS [orders]
                            ON [details].[order_id] = [orders].[id]
                        WHERE
                            CONCAT([details].[schema_name], '-policy-', [details].[table_name]) = @object_name
                        ORDER BY [orders].[order_date] DESC;

                        IF (@order_status = 'failed' OR @order_status = 'completed')
                            BEGIN
                                IF (@order_mode = 'upgrade')
                                    BEGIN
                                        UPDATE [mgmt_xtinfra].[infra_object_master]
                                        SET [version] = 0
                                        WHERE
                                            [name] = @object_name
                                            AND [type] = 'rlspolicy'

                                        SET @msg= (
                                            'Upgrading object with name: '
                                            + @object_name
                                            + ' and version: '
                                            + CAST(@object_version AS NVARCHAR(4))
                                        );
                                        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
                                        PRINT @msg;
                                        EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_run_to_version]
                                            'upgrade', 0, 9999, @schema_name, @predicate_function_name, @table_name, @parameter_list;
                                    END
                                ELSE IF (@order_mode = 'downgrade')
                                    BEGIN
                                        UPDATE [mgmt_xtinfra].[infra_object_master]
                                        SET [version] = 1
                                        WHERE
                                            [name] = @object_name
                                            AND [type] = 'rlspolicy'

                                        SET @msg= (
                                            'Downgrading object with name: '
                                            + @object_name
                                            + ' and version: '
                                            + CAST(@object_version AS NVARCHAR(4))
                                        );
                                        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
                                        PRINT @msg;
                                        EXEC [mgmt_xtinfra].[sp_infra_rlspolicy_run_to_version]
                                            'downgrade', 9999, 0, @schema_name, @predicate_function_name, @table_name, @parameter_list;
                                    END
                            END
                    END
                ELSE IF (@object_type = 'user')
                    BEGIN
                        SELECT TOP (1)
                            @order_mode = [orders].[mode],
                            @order_status = [orders].[status]
                        FROM [mgmt_xtinfra].[infra_orders_details_users] AS [details]
                        INNER JOIN [mgmt_xtinfra].[infra_orders_master] AS [orders]
                            ON [details].[order_id] = [orders].[id]
                        WHERE [details].[user_name] = @object_name
                        ORDER BY [orders].[order_date] DESC;

                        IF (@order_status = 'failed' OR @order_status = 'completed')
                            BEGIN
                                IF (@order_mode = 'upgrade')
                                    BEGIN
                                        UPDATE [mgmt_xtinfra].[infra_object_master]
                                        SET [version] = 0
                                        WHERE
                                            [name] = @object_name
                                            AND [type] = 'user'

                                        SET @msg= (
                                            'Upgrading object with name: '
                                            + @object_name
                                            + ' and version: '
                                            + CAST(@object_version AS NVARCHAR(4))
                                        );
                                        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
                                        PRINT @msg;
                                        EXEC [mgmt_xtinfra].[sp_infra_user_run_to_version]
                                            'upgrade', 0, 9999, @object_name;
                                    END
                                ELSE IF (@order_mode = 'downgrade')
                                    BEGIN
                                        UPDATE [mgmt_xtinfra].[infra_object_master]
                                        SET [version] = 1
                                        WHERE
                                            [name] = @object_name
                                            AND [type] = 'user'

                                        SET @msg= (
                                            'Downgrading object with name: '
                                            + @object_name
                                            + ' and version: '
                                            + CAST(@object_version AS NVARCHAR(4))
                                        );
                                        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
                                        PRINT @msg;
                                        EXEC [mgmt_xtinfra].[sp_infra_user_run_to_version]
                                            'downgrade', 9999, 0, @object_name;
                                    END
                            END
                    END
                SET @object_attributes= @object_type + ' '+@object_name + ' ' + @order_mode + ' ' + CAST(@object_version AS NVARCHAR(3));
                EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, @object_attributes, 'success';
            END TRY
            BEGIN CATCH
                SET @msg= ('Object with name: ' + @object_name + ' could not be updated due to error: ' + ERROR_MESSAGE());
                EXEC [mgmt_xtinfra].[sp_infra_job_log_execution_details] @log_detail_group, 'msg', @msg;
            END CATCH

            SET @current_count = @current_count + 1;
        END
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution @log_detail_group, @proc_name, 'success';
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

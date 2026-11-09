/*
Description: Lint fixed by MaX
This procedure will place a schema order for creation or update.
Author:
extern.nachtrub_daniel@allianz.de
Minor change:
Schema size check - 24/10/2024 jyothish.b@allianz.com
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_schema_order_create_or_update]
    (
        @workspace_name [nvarchar](256),
        @schema_name [nvarchar](256)
    )
AS
BEGIN
    DECLARE @schema_name_chk int
    DECLARE @workspace_name_chk int
    DECLARE @requestor nvarchar(128) = SESSION_USER
    DECLARE @order_id uniqueidentifier = NEWID()
    DECLARE @proc_name nvarchar(128) = 'sp_infra_schema_order_create_or_update'
    DECLARE @log_detail_group uniqueidentifier = NEWID()
    -- log order
    BEGIN TRY
        EXEC [mgmt_xtinfra].[sp_infra_job_log_execution] @log_detail_group, @proc_name, 'started';
        DECLARE @now datetime = GETDATE();
        DECLARE
            @destination_schema_name [nvarchar](43) = [mgmt_xtinfra].InfraGetWorkspaceSchemaName(@workspace_name, @schema_name);
        -- Character length checking for workspace and schema
        SET @workspace_name = TRIM(@workspace_name)
        SET @schema_name = TRIM(@schema_name)
        SET @schema_name_chk = (SELECT LEN(@schema_name))
        SET @workspace_name_chk = (SELECT LEN(@workspace_name))
        IF @schema_name_chk > 32
            BEGIN
            ;
                THROW 400005,
                'Number of Characters in the Schema name is not in the acceptable range, Number of Characters should be less than or equal to 32',
                1;
            END
        IF @workspace_name_chk > 10
            BEGIN
            ;
                THROW 400006,
                'Number of Characters in the Workspace name is not in the acceptable range, Number of Characters should be less than or equal to 10',
                1;
            END
        BEGIN
            EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details
                @log_detail_group, 'order_id', @order_id;
            EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details
                @log_detail_group, 'order_creation_date', @now;
            -- create order base
            INSERT INTO [mgmt_xtinfra].[infra_orders_master]
            (id, order_date, requestor, mode, type, status)
            VALUES
            (@order_id, @now, @requestor, 'upgrade', 'schema', 'new');
            -- attach type specific details
            INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemas]
            (order_id, workspace_name, schema_name)
            VALUES
            (@order_id, @workspace_name, @schema_name);
            --- link reader
            SET @order_id = NEWID();
            SET @now = GETDATE();
            -- let's hope we're not entering a race condition here with the schema creation itself
            INSERT INTO [mgmt_xtinfra].[infra_orders_master]
            (id, order_date, requestor, mode, type, status)
            VALUES
            (@order_id, @now, @requestor, 'upgrade', 'schemalink', 'new');
            INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemalinks]
            (
                order_id,
                source_schema_name,
                source_schema_role_name,
                destination_schema_name,
                destination_schema_role_name
            )
            VALUES
            (
                @order_id,
                @workspace_name,
                'reader',
                @destination_schema_name,
                'reader'
            );
            --- link writer
            SET @order_id = NEWID();
            SET @now = GETDATE();
            -- let's hope we're not entering a race condition here with the schema creation itself
            INSERT INTO [mgmt_xtinfra].[infra_orders_master]
            (id, order_date, requestor, mode, type, status)
            VALUES
            (@order_id, @now, @requestor, 'upgrade', 'schemalink', 'new');
            INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemalinks]
            (
                order_id,
                source_schema_name,
                source_schema_role_name,
                destination_schema_name,
                destination_schema_role_name
            )
            VALUES
            (
                @order_id,
                @workspace_name,
                'writer',
                @destination_schema_name,
                'writer'
            );
            --- link deployer
            SET @order_id = NEWID();
            SET @now = GETDATE();
            -- let's hope we're not entering a race condition here with the schema creation itself
            INSERT INTO [mgmt_xtinfra].[infra_orders_master]
            (id, order_date, requestor, mode, type, status)
            VALUES
            (@order_id, @now, @requestor, 'upgrade', 'schemalink', 'new');
            INSERT INTO [mgmt_xtinfra].[infra_orders_details_schemalinks]
            (
                order_id,
                source_schema_name,
                source_schema_role_name,
                destination_schema_name,
                destination_schema_role_name
            )
            VALUES
            (
                @order_id,
                @workspace_name,
                'deployer',
                @destination_schema_name,
                'deployer'
            );
            DECLARE
                @sql_stmt nvarchar(512)
                = 'EXECUTE [mgmt_xtinfra].[sp_infra_trigger_pipeline] '
                + QUOTENAME(@workspace_name, '''')
                + ', ''order_created'';';
            EXECUTE sp_executesql @sql_stmt;
            -- complete log
            EXEC [mgmt_xtinfra].sp_infra_job_log_execution
                @log_detail_group, @proc_name, 'success';
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

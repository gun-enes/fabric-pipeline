/*
Description: Enable/Disable connect privs for graceful restore operation

Author:
jyothish.b@allianz.com
*/
CREATE PROC [mgmt_xtinfra].[sp_infra_priv_capture] @ops_type NVARCHAR(8)
AS
BEGIN
    DECLARE @current_user NVARCHAR(100);
    DECLARE @now DATETIME = SYSDATETIME();
    DECLARE @priv_sql_counter INT = 1;
    DECLARE @priv_table_counter INT = 1;
    DECLARE @priv_sql_statement NVARCHAR(4000) = N'';
    SET @current_user = CURRENT_USER;
    DECLARE @proc_name varchar(100) = 'sp_infra_priv_capture';
    DECLARE @log_detail_group uniqueidentifier = NEWID();

    BEGIN TRY
        EXEC [mgmt_xtinfra].sp_infra_job_log_execution_details @log_detail_group, 'operation_type', @ops_type
        IF (@ops_type = 'BACKUP')
        BEGIN
            TRUNCATE TABLE [mgmt_xtinfra].[infra_conn_privs_capture];
            INSERT INTO [mgmt_xtinfra].[infra_conn_privs_capture]
            (
                [exec_id],
                [grant_priv_info],
                [revoke_priv_info],
                [exec_user],
                [exec_time]
            )
            SELECT
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
                pe.state_desc COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + ' ' + pe.permission_name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + ' TO [' + pr.name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + ']',
                'REVOKE ' + pe.permission_name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + ' FROM [' + pr.name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 + ']',
                @current_user,
                @now
            FROM sys.database_principals AS pr
            JOIN sys.database_permissions AS pe
                ON pe.grantee_principal_id = pr.principal_id
                AND pr.type_desc COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 IN ('EXTERNAL_USER','EXTERNAL_GROUP','SQL_USER')
            WHERE pr.name NOT IN ('sys','dbo','guest','INFORMATION_SCHEMA')
                AND pr.name NOT LIKE '%mgmt' AND pr.name NOT LIKE '%01-deploy'
                AND pe.permission_name = 'CONNECT';

        -- Disable CONNECT privilege to users except DBA Team
            SET @priv_sql_counter = 1;
            SET @priv_table_counter = (
                SELECT COUNT(*)
                FROM [mgmt_xtinfra].[infra_conn_privs_capture]
            );

            WHILE @priv_sql_counter <= @priv_table_counter
            BEGIN
                SET @priv_sql_statement = (
                    SELECT [revoke_priv_info]
                    FROM [mgmt_xtinfra].[infra_conn_privs_capture]
                    WHERE [exec_id] = @priv_sql_counter
                );
                PRINT @priv_sql_statement;
                EXEC sp_executesql @priv_sql_statement;
                SET @priv_sql_counter += 1;
            END;
        END
        -- Enable CONNECT privilege to users
        IF (@ops_type = 'RESTORE')
        BEGIN
            SET @priv_sql_counter = 1;
            SET @priv_table_counter = (
                SELECT COUNT(*)
                FROM [mgmt_xtinfra].[infra_conn_privs_capture]
                );

            WHILE @priv_sql_counter <= @priv_table_counter
            BEGIN
                SET @priv_sql_statement = (
                    SELECT [grant_priv_info]
                    FROM [mgmt_xtinfra].[infra_conn_privs_capture]
                    WHERE [exec_id] = @priv_sql_counter
                );
                PRINT @priv_sql_statement;
                EXEC sp_executesql @priv_sql_statement;
                SET @priv_sql_counter += 1;
            END;
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
	END CATCH;
END

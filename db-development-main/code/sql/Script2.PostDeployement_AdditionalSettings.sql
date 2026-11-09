-- This file contains SQL statements that will be executed after the build script.
BEGIN
     -- Initialize infra_script_master
    DECLARE @now DateTime =(select SYSDATETIME())
    DECLARE @db_name varchar(1000) =  db_name();
    DELETE FROM mgmt_xtinfra.infra_script_master;
    INSERT INTO mgmt_xtinfra.infra_script_master (script_id ,db_name,scriptversionid ,script_status ,created )
    SELECT 1,@db_name,'V.01','current',@now ;

    --permissions that must be addded in post script as SQL Package won't build:
    GRANT SHOWPLAN to [Role_SHOWPLAN];
    GRANT VIEW ANY SENSITIVITY CLASSIFICATION,ALTER ANY SENSITIVITY CLASSIFICATION TO [Role_SchemaDeployer];
    GRANT ADMINISTER DATABASE BULK OPERATIONS TO [Role_AdministerDatabaseBulkOperations];
    GRANT ADMINISTER DATABASE BULK OPERATIONS TO [Role_SparkConnector];
    GRANT ALTER ANY DATASPACE to [Role_AlterAnyDataspace];
    SET @cmd = 'GRANT SELECT ON DATABASE::[' + @db_name + '] TO [Role_SchemaDeployer];';
    EXEC (@cmd);

    --Enabling Query store in mgmt pool running once
    PRINT ('Enabling Query store in mgmt pool');
    SET @cmd = N'ALTER DATABASE ' + @db_name + ' SET QUERY_STORE = ON';
    EXEC (@cmd);
    --Enabling Auto stats in mgmt pool running once
    PRINT ('Enabling Auto stats in mgmt pool');
    SET @cmd = N'ALTER DATABASE ' + @db_name + ' SET AUTO_CREATE_STATISTICS ON';
    EXEC (@cmd);

    -- and CREATE MANAGE IDENTITY IF NOT ALREADY THERE:
    IF NOT EXISTS (SELECT 1 FROM sys.database_scoped_credentials WHERE  credential_identity = 'Managed Identity')
    BEGIN
        PRINT 'credential_identity: Managed Identity does not exists. creating new Managed Identity in DATABASE SCOPED CREDENTIAL ManagedIdentity';
        CREATE DATABASE SCOPED CREDENTIAL ManagedIdentity WITH IDENTITY = 'Managed Identity';
    END
    ELSE
    BEGIN
        PRINT 'Manage Identity already exists';
    END
END

--Check if backup external data source is set correctly
CREATE PROCEDURE [UnitTests].[test_verification_check_backup_external_data_source]
AS
BEGIN
    PRINT ('Executing Test: test_verification_check_backup_external_data_source')
    DECLARE @backup_eds_name NVARCHAR(128) = '---';

    SELECT @backup_eds_name = [value]
    FROM [mgmt_xtinfra].[infra_global_config]
    WHERE [key] = 'backup_external_data_source'

    -- To check if backup external data source is defined
    EXEC [tSQLt_synapse].[AssertNotEqualsString] '---', @backup_eds_name;

    -- Check if backup external data source is set to mgmt-bck or mgmt-cur based on the existence of mgmt-bck external data source in the database.
    IF
        EXISTS (
            SELECT 1
            FROM [sys].[external_data_sources]
            WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'mgmt-bck'
        )
        BEGIN
            PRINT ('Backup external data source should be mgmt-bck')
            EXEC [tSQLt_synapse].[AssertEqualsString] 'mgmt-bck', @backup_eds_name;
        END
    ELSE
        BEGIN
            PRINT ('Backup external data source should be mgmt-cur')
            EXEC [tSQLt_synapse].[AssertEqualsString] 'mgmt-cur', @backup_eds_name;
        END
END;
GO

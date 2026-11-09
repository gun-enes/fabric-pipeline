--Check if external tables can be created with the mgmt data source
-- pointing to the curated storage account using a CETAS statement.
CREATE PROCEDURE [UnitTests].[test_verification_mgmt_curated_sa_write_access_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_mgmt_curated_sa_write_access_check')
    -- Checks if the following CETAS statement fails or not.
    EXEC [tSQLt_synapse].[ExpectNoException] 'Failed to execute CETAS statement using the curated storage account'
    CREATE EXTERNAL TABLE [UnitTests].[MgmtCuratedDataSourceTest]
    WITH (
        LOCATION = '/test-external-table-creation/'
        ,DATA_SOURCE = [mgmt-cur]
        ,FILE_FORMAT = SynapseParquetFormat
    ) AS
        SELECT GETDATE() AS execution_time;
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_mgmt_curated_sa_write_access_check]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_mgmt_curated_sa_write_access_check')
    DROP EXTERNAL TABLE [UnitTests].[MgmtCuratedDataSourceTest]
END;
GO

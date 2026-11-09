--Check if symmetric keys are generated correctly
CREATE PROCEDURE [UnitTests].[test_verification_db_masterkey]
AS
BEGIN
    PRINT ('Executing Test: test_verification_db_masterkey')
    DECLARE @Msg NVARCHAR(MAX);

    IF NOT EXISTS (
        SELECT 1
        FROM sys.symmetric_keys
        WHERE name COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = '##MS_DatabaseMasterKey##'
    )
    BEGIN
        SET @Msg = 'No master key found in the database.'
        EXEC [tSQLt_synapse].[Fail] @Msg;
    END
END

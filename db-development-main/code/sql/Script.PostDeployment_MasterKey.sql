BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM sys.symmetric_keys
        WHERE name = '##MS_DatabaseMasterKey##'
    )
    BEGIN
        PRINT ('No master key found, creating a new one')
        CREATE MASTER KEY
    END
END

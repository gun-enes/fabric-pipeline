-- TSQL statements that will be executed before the build script.
-- Note : This script need to be removed once we deployed V1.8.1 version
BEGIN
    BEGIN TRY
        IF
            EXISTS (
                SELECT 1 FROM [sys].[objects]
                WHERE
                    [object_id] = OBJECT_ID(N'mgmt_xtinfra.infra_dr_backup_master')
            )
            BEGIN
                DROP TABLE [mgmt_xtinfra].[infra_dr_backup_master];
                PRINT ('mgmt_xtinfra.infra_dr_backup_master has been dropped');
            END
    END TRY
    BEGIN CATCH
        PRINT ('Table mgmt_xtinfra.infra_dr_backup_master is not present');
    END CATCH
END

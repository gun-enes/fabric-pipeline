/*
Description:
This stored procedure is used to validate the DR Backup in Simplifi
Author:
jyothish.b@allianz.com
*/
CREATE PROCEDURE [mgmt_xtinfra].[sp_infra_dr_backup_validation]
AS
BEGIN
    DECLARE @mismatch_details NVARCHAR(MAX);

    SELECT @mismatch_details =
        STRING_AGG(table_schema + '.' + table_name, ',')
    FROM [mgmt_xtinfra].[infra_dr_backup_master]
    WHERE [hash_validation] = 1
    AND COALESCE(source_table_hash, 0x0) <> COALESCE(target_table_hash, 0x0);

    IF @mismatch_details IS NOT NULL
    BEGIN
        RAISERROR(
            'Mismatch detected on the following tables:%s',
            16,
            1,
            @mismatch_details
        );
    END
    ELSE
    BEGIN
        PRINT 'No mismatch detected: DR Backup Validation completed successfully';
    END
END
GO

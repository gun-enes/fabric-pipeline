--Check if there is any data loss or inconsistency in backup and
-- restore stored procedures.
CREATE PROCEDURE [UnitTests].[test_verification_cetas_backup_restore]
AS
BEGIN
    PRINT ('Executing Test: test_verification_cetas_backup_restore')

    -- create a table with all data types to test backup/restore
    CREATE TABLE [UnitTests].[all_types_table_to_restore]
    (
        [col_bigint] [bigint] NULL,
        [col_binary] [binary](1) NULL,
        [col_bit] [bit] NULL,
        [col_char] [char](100) NULL,
        [col_date] [date] NULL,
        [col_datetime] [datetime] NULL,
        [col_datetime2] [datetime2](3) NULL,
        [col_datetimeoffset] [datetimeoffset](3) NULL,
        [col_decimal] [decimal](10, 5) NULL,
        [col_float] [float] NULL,
        [col_int] [int] NULL,
        [col_nchar] [nchar](100) NULL,
        [col_numeric] [numeric](10, 5) NULL,
        [col_nvarchar] [nvarchar](4000) NULL,
        [col_real] [real] NULL,
        [col_smalldatetime] [smalldatetime] NULL,
        [col_smallint] [smallint] NULL,
        [col_money] [money] NULL,
        [col_smallmoney] [smallmoney] NULL,
        [col_sysname] [sysname] NULL,
        [col_time] [time](7) NULL,
        [col_tinyint] [tinyint] NULL,
        [col_uniqueidentifier] [uniqueidentifier] NULL,
        [col_varbinary] [varbinary](1) NULL,
        [col_varchar] [varchar](8000) NULL
    )
    WITH
    (
        DISTRIBUTION = ROUND_ROBIN,
        CLUSTERED COLUMNSTORE INDEX
    );

    -- populate original table with data
    INSERT INTO [UnitTests].[all_types_table_to_restore]
    VALUES (
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
    );

    INSERT INTO [UnitTests].[all_types_table_to_restore]
    VALUES (
        1,
        0x01,
        1,
        'A',
        '2025-01-01',
        '2025-01-01 00:00:00',
        '2025-01-01T00:00:00.0000000',
        '2025-01-01T00:00:00.0000000+00:00',
        123.450000,
        1.23,
        42,
        N'Ä',
        999.99,
        N'ĞİıİÇĞİİŞŞşöüöİğçÃÎÃÂIıİi🙃ÇaĞ',
        3.14,
        '2025-01-01 00:00:00',
        10,
        100.00,
        5.50,
        'sys',
        '12:00:00',
        255,
        'b9c51c29-c2f7-4735-ba70-49bc5c780ba1',
        0x02,
        'test'
    );

    -- backup the original table
    DECLARE @filename nvarchar(100) = 'env_sensitive_test_' + CAST(FORMAT(GETDATE(), 'yyyy-MM-ddTHH:mm:ssZ') AS nvarchar(50));
    EXEC [mgmt_xtinfra].[sp_infra_backup_single_table] 'UnitTests', 'all_types_table_to_restore', @filename;

    -- create duplicate table as original table will be restored
    SELECT *
    INTO [UnitTests].[all_types_table_duplicate]
    FROM [UnitTests].[all_types_table_to_restore]

    -- restore the table
    EXEC [mgmt_xtinfra].[sp_infra_restore_single_table] 'UnitTests', 'all_types_table_to_restore', '';

    DECLARE @line nvarchar(MAX);

    PRINT ('Printing [UnitTests].[all_types_table_duplicate]');
    SELECT
        @line = STRING_AGG(
            CAST(
                CONCAT(
                    [col_bigint], ' | ',
                    [col_binary], ' | ',
                    [col_bit], ' | ',
                    [col_char], ' | ',
                    [col_date], ' | ',
                    [col_datetime], ' | ',
                    [col_datetime2], ' | ',
                    [col_datetimeoffset], ' | ',
                    [col_decimal], ' | ',
                    [col_float], ' | ',
                    [col_int], ' | ',
                    [col_nchar], ' | ',
                    [col_numeric], ' | ',
                    [col_nvarchar], ' | ',
                    [col_real], ' | ',
                    [col_smalldatetime], ' | ',
                    [col_smallint], ' | ',
                    [col_money], ' | ',
                    [col_smallmoney], ' | ',
                    [col_sysname], ' | ',
                    [col_time], ' | ',
                    [col_tinyint], ' | ',
                    [col_uniqueidentifier], ' | ',
                    [col_varbinary], ' | ',
                    [col_varchar]
                ) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS nvarchar(MAX)
            ), CHAR(10
            )
        )
    FROM [UnitTests].[all_types_table_duplicate];

    PRINT @line;

    PRINT ('Printing [UnitTests].[all_types_table_to_restore]');
    SELECT
        @line = STRING_AGG(
            CAST(
                CONCAT(
                    [col_bigint], ' | ',
                    [col_binary], ' | ',
                    [col_bit], ' | ',
                    [col_char], ' | ',
                    [col_date], ' | ',
                    [col_datetime], ' | ',
                    [col_datetime2], ' | ',
                    [col_datetimeoffset], ' | ',
                    [col_decimal], ' | ',
                    [col_float], ' | ',
                    [col_int], ' | ',
                    [col_nchar], ' | ',
                    [col_numeric], ' | ',
                    [col_nvarchar], ' | ',
                    [col_real], ' | ',
                    [col_smalldatetime], ' | ',
                    [col_smallint], ' | ',
                    [col_money], ' | ',
                    [col_smallmoney], ' | ',
                    [col_sysname], ' | ',
                    [col_time], ' | ',
                    [col_tinyint], ' | ',
                    [col_uniqueidentifier], ' | ',
                    [col_varbinary], ' | ',
                    [col_varchar]
                ) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS nvarchar(MAX)
            ), CHAR(10
            )
        )
    FROM [UnitTests].[all_types_table_to_restore];

    PRINT @line;

    DECLARE @originalCount int;
    DECLARE @restoreCount int;

    SELECT @originalCount = COUNT(*)
    FROM [UnitTests].[all_types_table_duplicate];

    SELECT @restoreCount = COUNT(*)
    FROM [UnitTests].[all_types_table_to_restore];

    -- populate diff table to compare original and restored tables
    SELECT *
    INTO [#BackupRestoreDiff]
    FROM (
        (
            SELECT *
            FROM [UnitTests].[all_types_table_to_restore]
            EXCEPT
            SELECT *
            FROM [UnitTests].[all_types_table_duplicate]
        )
        UNION ALL
        (
            SELECT *
            FROM [UnitTests].[all_types_table_duplicate]
            EXCEPT
            SELECT *
            FROM [UnitTests].[all_types_table_to_restore]
        )
    ) AS [diff];

    -- assert tables are equal
    IF EXISTS (SELECT 1 FROM [#BackupRestoreDiff]) OR (@originalCount <> @restoreCount)
        BEGIN
            PRINT ('Original and restored tables are not equal!');

            INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
            VALUES ('Original and restored tables are not equal!', 'non-empty diff table');
        -- failure
        END

    -- assert hash calculation is correct
    DECLARE @sourceHash varbinary(8000);
    DECLARE @targetHash varbinary(8000);

    SELECT
        @sourceHash
        = HASHBYTES(
            'SHA2_256',
            CAST(SUM(CAST(BINARY_CHECKSUM(*) AS bigint)) AS varchar(MAX))
        )
    FROM [UnitTests].[all_types_table_duplicate];

    SELECT
        @targetHash
        = HASHBYTES(
            'SHA2_256',
            CAST(SUM(CAST(BINARY_CHECKSUM(*) AS bigint)) AS varchar(MAX))
        )
    FROM [UnitTests].[all_types_table_to_restore];

    IF (@sourceHash <> @targetHash)
        BEGIN
            PRINT ('Hash validation failed!');

            INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
            VALUES ('Hash validation failed!', 'hash validation failure');
        -- failure
        END
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_cetas_backup_restore]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_cetas_backup_restore')
    DROP TABLE [UnitTests].[all_types_table_to_restore];
    DROP TABLE [UnitTests].[all_types_table_duplicate];
    DROP EXTERNAL TABLE [UnitTests].[exttable_all_types_table_to_restore];
END;
GO

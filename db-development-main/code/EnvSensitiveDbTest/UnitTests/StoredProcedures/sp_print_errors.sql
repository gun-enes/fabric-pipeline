CREATE PROCEDURE [UnitTests].[sp_print_errors]
AS
BEGIN
    -- Check if [Errors] table exists
    IF OBJECT_ID('UnitTests.Errors') IS NULL
    BEGIN
        PRINT 'No [UnitTests].[Errors] table found.';
    END;

    IF EXISTS (SELECT 1 FROM [UnitTests].[Errors])
    BEGIN
        PRINT('');
        PRINT('Detailed Errors from Verification:');
        PRINT('---------------------------------------------');

        IF OBJECT_ID('tempdb..#ErrorsPrint') IS NOT NULL
            DROP TABLE #ErrorsPrint;

        SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS [seq],
               [VerificationError],
               [Value]
        INTO #ErrorsPrint
        FROM [UnitTests].[Errors];

        DECLARE @row INT = 1;
        DECLARE @max INT = (SELECT COUNT(*) FROM #ErrorsPrint);
        DECLARE @err NVARCHAR(4000), @val NVARCHAR(4000);

        WHILE @row <= @max
        BEGIN
            SELECT @err = [VerificationError], @val = [Value]
            FROM #ErrorsPrint WHERE [seq] = @row;

            PRINT ISNULL(@err, '(NULL)')
                  + SPACE(60 - LEN(ISNULL(@err, '')))
                  + ISNULL(@val, '(NULL)');

            SET @row += 1;
        END;

        DROP TABLE #ErrorsPrint;

    END
    ELSE
    BEGIN
        PRINT('No verification errors detected.');
    END;
    PRINT('---------------------------------------------');
END;
GO

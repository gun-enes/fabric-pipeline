CREATE PROCEDURE [tSQLt_synapse].[AssertNotEqualsString]
    @expected NVARCHAR(MAX),
    @actual NVARCHAR(MAX)
AS
BEGIN
    IF (
        (@expected = @actual)
        OR (@expected IS NULL AND @actual IS NULL)
    )
        BEGIN
            DECLARE @Msg NVARCHAR(MAX);
            SET
                @Msg = 'Expected actual value to not '
                + COALESCE('equal <' + @expected + '>', 'be NULL')
                + '.';
            EXEC [tSQLt_synapse].[Fail] @Msg;
        END
END;

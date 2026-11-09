CREATE PROCEDURE [tSQLt_synapse].[AssertEqualsInt]
    @expected int,
    @actual int
AS
BEGIN
    IF (
        (@expected <> @actual)
        OR (@expected IS NULL AND @actual IS NOT NULL)
        OR (@expected IS NOT NULL AND @actual IS NULL)
    )
        BEGIN
            DECLARE @Msg nvarchar(MAX);
            SELECT
                @Msg = 'Expected: <' + ISNULL(CAST(@expected AS nvarchar(MAX)), 'NULL')
                + '> but was: <' + ISNULL(CAST(@actual AS nvarchar(MAX)), 'NULL') + '>';
            EXEC [tSQLt_synapse].[Fail] @Msg;
        END
END;

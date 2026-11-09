-- Modified by Deep Network GmbH to make it compatible with Synapse
CREATE PROCEDURE [tSQLt_synapse].[AssertEqualsString]
    @expected NVARCHAR(MAX),
    @actual NVARCHAR(MAX)
AS
BEGIN
    IF (
        (@expected <> @actual)
        OR (@expected IS NULL AND @actual IS NOT NULL)
        OR (@expected IS NOT NULL AND @actual IS NULL)
    )
        BEGIN
            DECLARE @Msg NVARCHAR(MAX);
            SELECT
                @Msg = 'Expected: <' + ISNULL(@expected, 'NULL')
                + '> but was: <' + ISNULL(@actual, 'NULL') + '>';
            EXEC [tSQLt_synapse].[Fail] @Msg;
        END
END;

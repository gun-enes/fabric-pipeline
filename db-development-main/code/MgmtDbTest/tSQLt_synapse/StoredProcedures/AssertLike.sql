-- Modified by Deep Network GmbH to make it compatible with Synapse
CREATE PROCEDURE [tSQLt_synapse].[AssertLike]
    @expected_pattern NVARCHAR(MAX),
    @actual NVARCHAR(MAX)
AS
BEGIN
    IF (LEN(@expected_pattern) > 4000)
        BEGIN
            RAISERROR ('@expected_pattern may not exceed 4000 characters.', 16, 10);
        END;

    DECLARE @message NVARCHAR(MAX);
    IF (
        (@actual NOT LIKE @expected_pattern)
        OR (@actual IS NULL AND @expected_pattern IS NOT NULL)
        OR (@actual IS NOT NULL AND @expected_pattern IS NULL)
    )
        BEGIN
            SELECT
                @message = 'Expected: <' + ISNULL(@expected_pattern, 'NULL') + '>'
                + ' but was: <' + ISNULL(@actual, 'NULL') + '>';
            EXEC [tSQLt_synapse].[Fail] @message;
        END
END;

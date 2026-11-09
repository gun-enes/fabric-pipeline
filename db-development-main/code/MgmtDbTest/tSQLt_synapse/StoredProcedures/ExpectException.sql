-- Modified by Deep Network GmbH to make it compatible with Synapse
CREATE PROCEDURE [tSQLt_synapse].[ExpectException]
    @ExpectedMessage NVARCHAR(MAX),
    @ExpectedSeverity INT,
    @ExpectedState INT,
    @Message NVARCHAR(MAX),
    @ExpectedErrorNumber INT
AS
BEGIN
    -- The severity of exceptions coming from THROW statement are always 16
    IF (EXISTS (SELECT 1 FROM #ExpectException WHERE [ExpectException] = 1))
        BEGIN
        -- we are deleting in order not to confuse test runner to handle the exception inside #ExpectException table
            DELETE #ExpectException;
            THROW 50001, 'Each test can only contain one call to tSQLt_synapse.ExpectException.', 101;
        END;

    INSERT INTO #ExpectException (
        [ExpectException], [ExpectedMessage], [ExpectedSeverity], [ExpectedState], [ExpectedErrorNumber], [FailMessage]
    )
    VALUES (1, @ExpectedMessage, @ExpectedSeverity, @ExpectedState, @ExpectedErrorNumber, @Message);
END;

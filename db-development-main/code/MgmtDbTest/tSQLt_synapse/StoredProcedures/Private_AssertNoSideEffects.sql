-- Modified by Deep Network GmbH to make it compatible with Synapse
CREATE PROCEDURE [tSQLt_synapse].[Private_AssertNoSideEffects]
    @BeforeExecutionObjectSnapshotTableName NVARCHAR(MAX),
    @AfterExecutionObjectSnapshotTableName NVARCHAR(MAX),
    @test_name NVARCHAR(MAX)
AS
BEGIN
    IF (OBJECT_ID('tempdb..#ObjectDiscrepancies') IS NOT NULL)
        DROP TABLE #ObjectDiscrepancies;

    DECLARE @message NVARCHAR(MAX);
    DECLARE @cmd NVARCHAR(MAX);

    SET @cmd = 'SELECT * INTO #ObjectDiscrepancies
      FROM(
        (SELECT ''Deleted'' [Status], B.* FROM ' + @BeforeExecutionObjectSnapshotTableName + ' AS B EXCEPT SELECT ''Deleted'' [Status],* FROM ' + @AfterExecutionObjectSnapshotTableName + ' AS A)
         UNION ALL
        (SELECT ''Added'' [Status], A.* FROM ' + @AfterExecutionObjectSnapshotTableName + ' AS A EXCEPT SELECT ''Added'' [Status], * FROM ' + @BeforeExecutionObjectSnapshotTableName + ' AS B)
      )D;'
    EXEC [sp_executesql] @cmd;

    IF (EXISTS (SELECT 1 FROM #ObjectDiscrepancies))
        BEGIN
            SELECT
                @message
                = STRING_AGG(
                    CAST(
                        CONCAT(
                            'Status: ' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
                            [Status] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
                            ' ObjectId: ' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 ,
                            CAST([ObjectId] AS NVARCHAR(100)) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
                            ' SchemaName: ' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
                            [SchemaName],
                            ' ObjectName: ' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
                            [ObjectName],
                            ' ObjectType: ' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
                            [ObjectType]
                        ) AS NVARCHAR(MAX)
                    ),
                    CHAR(13)
                )
            FROM #ObjectDiscrepancies;
            SET
                @message
                = 'After the test ['
                + @test_name
                + '] executed, there were unexpected or missing objects in the database'
                + CHAR(13) + @message;
            THROW 50002, @message, 102;
        END
END;

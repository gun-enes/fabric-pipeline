-- Modified by Deep Network GmbH to make it compatible with Synapse
CREATE PROCEDURE [tSQLt_synapse].[AssertEqualsTable]
    @expected NVARCHAR(MAX),
    @actual NVARCHAR(MAX)
AS
BEGIN

    EXEC [tSQLt_synapse].[AssertObjectExists] @expected;
    EXEC [tSQLt_synapse].[AssertObjectExists] @actual;

    DECLARE @ResultTable NVARCHAR(MAX);
    DECLARE @ResultTableWithSchema NVARCHAR(MAX);
    DECLARE @ResultColumn NVARCHAR(MAX);
    DECLARE @ColumnList NVARCHAR(MAX);
    DECLARE @UnequalRowsExist INT;
    DECLARE @CombinedMessage NVARCHAR(MAX);
    DECLARE @Cmd NVARCHAR(MAX);


    SELECT @ResultTable = 'result_table';
    SELECT @ResultColumn = '_m_';
    SELECT @ResultTableWithSchema = 'tSQLt_synapse.' + @ResultTable;

    SET @Cmd = '
     SELECT TOP(0) ''>'' AS ' + @ResultColumn + ', Expected.* INTO ' + @ResultTableWithSchema + '
       FROM ' + @expected + ' AS Expected RIGHT JOIN ' + @expected + ' AS X ON 1=0; '
    EXEC [sp_executesql] @Cmd;

    SELECT
        @ColumnList
        = STRING_AGG(CAST(CASE WHEN [system_type_id] = TYPE_ID('datetime') THEN ';DATETIME columns are unsupported!;' ELSE QUOTENAME([name]) END COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)), ',')
    FROM [sys].[columns]
    WHERE
        [object_id] = OBJECT_ID(@ResultTableWithSchema)
        AND [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 <> @ResultColumn

    BEGIN TRY
        SET @Cmd = 'DECLARE @EatResult INT; SELECT @EatResult = COUNT(1) FROM ' + @ResultTableWithSchema + ' GROUP BY ' + @ColumnList + ';';
        EXEC [sp_executesql] @Cmd;
    END TRY
    BEGIN CATCH
        THROW 50003, 'The table contains a datatype that is not supported for tSQLt.AssertEqualsTable', 103;
    END CATCH

    EXEC [tSQLt_synapse].[Private_CompareTables]
        @Expected = @expected,
        @Actual = @actual,
        @ResultTable = @ResultTable,
        @ResultTableSchema = 'tSQLt_synapse',
        @ColumnList = @ColumnList,
        @MatchIndicatorColumnName = @ResultColumn;

    SET @Cmd = 'DROP TABLE ' + @ResultTableWithSchema;
    EXEC [sp_executesql] @Cmd;
END;

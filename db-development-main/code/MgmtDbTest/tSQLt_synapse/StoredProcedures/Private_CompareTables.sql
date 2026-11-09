-- Modified by Deep Network GmbH to make it compatible with Synapse
CREATE PROCEDURE [tSQLt_synapse].[Private_CompareTables]
    @Expected NVARCHAR(MAX),
    @Actual NVARCHAR(MAX),
    @ResultTable NVARCHAR(MAX),
    @ResultTableSchema NVARCHAR(MAX),
    @ColumnList NVARCHAR(MAX),
    @MatchIndicatorColumnName NVARCHAR(MAX)
AS
BEGIN
    DECLARE @cmd NVARCHAR(MAX);
    DECLARE @ResultTableWithSchema VARCHAR(MAX) = @ResultTableSchema + '.' + @ResultTable;
    DECLARE @RestoredRowIndexCounterColName NVARCHAR(MAX);
    SET @RestoredRowIndexCounterColName = @MatchIndicatorColumnName + '_RR';

    SELECT
        @cmd
        = '
    INSERT INTO ' + @ResultTableWithSchema + ' (' + @MatchIndicatorColumnName + ', ' + @ColumnList + ')
    SELECT
      CASE
        WHEN RestoredRowIndex.' + @RestoredRowIndexCounterColName + ' <= CASE WHEN [_{Left}_]<[_{Right}_] THEN [_{Left}_] ELSE [_{Right}_] END
         THEN ''=''
        WHEN RestoredRowIndex.' + @RestoredRowIndexCounterColName + ' <= [_{Left}_]
         THEN ''<''
        ELSE ''>''
      END AS ' + @MatchIndicatorColumnName + ', ' + @ColumnList + '
    FROM(
      SELECT SUM([_{Left}_]) AS [_{Left}_],
             SUM([_{Right}_]) AS [_{Right}_],
             ' + @ColumnList + '
      FROM (
        SELECT 1 AS [_{Left}_], 0[_{Right}_], ' + @ColumnList + '
          FROM ' + @Expected + '
        UNION ALL
        SELECT 0[_{Left}_], 1 AS [_{Right}_], ' + @ColumnList + '
          FROM ' + @Actual + '
      ) AS X
      GROUP BY ' + @ColumnList + '
    ) AS CollapsedRows
    CROSS APPLY (
       SELECT TOP(CASE WHEN [_{Left}_]>[_{Right}_] THEN [_{Left}_]
                       ELSE [_{Right}_] END)
              ROW_NUMBER() OVER(ORDER BY(SELECT 1))
         FROM (SELECT 1
                 FROM ' + @Actual + ' UNION ALL SELECT 1 FROM ' + @Expected + ') X(X)
              ) AS RestoredRowIndex(' + @RestoredRowIndexCounterColName + ');';
    EXEC [sp_executesql] @cmd;

    SET
        @cmd = 'SET @r =
         CASE WHEN EXISTS(
                  SELECT 1
                    FROM ' + @ResultTableWithSchema
        + ' WHERE ' + @MatchIndicatorColumnName + ' IN (''<'', ''>''))
              THEN 1 ELSE 0
         END';
    DECLARE @UnequalRowsExist INT;
    EXEC [sp_executesql] @cmd, N'@r INT OUTPUT', @UnequalRowsExist OUTPUT;

    IF @UnequalRowsExist > 0
        BEGIN
            EXEC [tSQLt_synapse].[Private_PrintTable] @ResultTableSchema, @ResultTable;
            SET @cmd = 'DROP TABLE ' + @ResultTableWithSchema + ';'
            EXEC [sp_executesql] @cmd;
            EXEC [tSQLt_synapse].[Fail] 'There exists unequal rows!';
        END;
END;

PRINT('Deleting tSQLt_synapse stored procedures');
DECLARE @drop_sprocs nvarchar(max);
SELECT @drop_sprocs = STRING_AGG(CAST(CONCAT(N'DROP PROCEDURE [tSQLt_synapse].', QUOTENAME(p.name), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)), CHAR(13))
FROM sys.schemas AS s
INNER JOIN sys.procedures AS p
ON s.[schema_id] = p.[schema_id]
WHERE s.name = 'tSQLt_synapse'

PRINT @drop_sprocs
EXEC sys.sp_executesql @drop_sprocs;
GO

PRINT('Deleting tSQLt_synapse tables');
DECLARE @drop_tables nvarchar(max);
SELECT @drop_tables = STRING_AGG(CAST(CONCAT(N'DROP TABLE [tSQLt_synapse].', QUOTENAME(t.name), N';') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 AS NVARCHAR(MAX)), CHAR(13))
FROM sys.schemas AS s
INNER JOIN sys.tables AS t
ON s.[schema_id] = t.[schema_id]
WHERE s.name = 'tSQLt_synapse'

PRINT @drop_tables
EXEC sys.sp_executesql @drop_tables;
GO

PRINT('Deleting tSQLt_synapse schema');
DROP SCHEMA [tSQLt_synapse]
GO

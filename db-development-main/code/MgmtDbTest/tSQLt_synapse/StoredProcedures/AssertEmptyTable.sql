-- Modified by Deep Network GmbH to make it compatible with Synapse
CREATE PROCEDURE [tSQLt_synapse].[AssertEmptyTable]
    @table_name NVARCHAR(MAX)
AS
BEGIN
    EXEC [tSQLt_synapse].[AssertObjectExists] @table_name;

    DECLARE @full_name NVARCHAR(MAX);
    IF (OBJECT_ID(@table_name) IS NULL AND OBJECT_ID('tempdb..' + @table_name) IS NOT NULL)
        BEGIN
            SET @full_name = CASE WHEN LEFT(@table_name, 1) = '[' THEN @table_name ELSE QUOTENAME(@table_name) END;
        END;
    ELSE
        BEGIN
            SET @full_name = QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(@table_name))) + '.' + QUOTENAME(OBJECT_NAME(OBJECT_ID(@table_name)));
        END;

    DECLARE @cmd NVARCHAR(MAX);
    DECLARE @exists INT;
    SET @cmd = 'SELECT @exists = CASE WHEN EXISTS(SELECT 1 FROM ' + @full_name + ') THEN 1 ELSE 0 END;'
    EXEC [sp_executesql] @cmd, N'@exists INT OUTPUT', @exists OUTPUT;

    IF (@exists = 1)
        BEGIN
            IF (OBJECT_ID(@table_name) IS NULL AND OBJECT_ID('tempdb..' + @table_name) IS NOT NULL)
                BEGIN
                    SET @cmd = 'SELECT * FROM ' + @full_name + ';'
                    EXEC [sp_executesql] @cmd
                END
            ELSE
                BEGIN
                    DECLARE @table_name_without_schema NVARCHAR(MAX) = OBJECT_NAME(OBJECT_ID(@table_name));
                    DECLARE @schema_name NVARCHAR(MAX) = OBJECT_SCHEMA_NAME(OBJECT_ID(@table_name));
                    EXEC [tSQLt_synapse].[Private_PrintTable] @schema_name, @table_name_without_schema;
                END
            DECLARE @message NVARCHAR(MAX);
            SET @message = @full_name + ' was not empty';
            EXEC [tSQLt_synapse].[Fail] @message;
        END
END

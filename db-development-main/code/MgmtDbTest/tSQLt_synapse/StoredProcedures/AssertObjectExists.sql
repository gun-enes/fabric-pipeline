-- Modified by Deep Network GmbH to make it compatible with Synapse
CREATE PROCEDURE [tSQLt_synapse].[AssertObjectExists]
    @object_name NVARCHAR(MAX)
AS
BEGIN
    DECLARE @message NVARCHAR(MAX);
    IF (@object_name LIKE '#%')
        BEGIN
            IF OBJECT_ID('tempdb..' + @object_name) IS NULL
                BEGIN
                    SELECT @message = '''' + COALESCE(@object_name, 'NULL') + ''' does not exist';
                    EXEC [tSQLt_synapse].[Fail] @message;
                END;
        END
    ELSE
        BEGIN
            IF OBJECT_ID(@object_name) IS NULL
                BEGIN
                    SELECT @message = '''' + COALESCE(@object_name, 'NULL') + ''' does not exist';
                    EXEC [tSQLt_synapse].[Fail] @message;
                END;
        END;
END;

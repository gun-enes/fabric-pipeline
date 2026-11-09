-- Modified by Deep Network GmbH to make it compatible with Synapse
CREATE PROCEDURE [tSQLt_synapse].[AssertObjectDoesNotExist]
    @object_name NVARCHAR(MAX)
AS
BEGIN
    DECLARE @message NVARCHAR(MAX);
    IF (OBJECT_ID(@object_name) IS NOT NULL OR (@object_name LIKE '#%' AND OBJECT_ID('tempdb..' + @object_name) IS NOT NULL))
        BEGIN
            SELECT @message = '''' + @object_name + ''' does exist!';
            EXEC [tSQLt_synapse].[Fail] @message;
        END;
END;

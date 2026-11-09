-- This file contains SQL statements that will be executed after the build script.
BEGIN
    DECLARE @db_name nvarchar(1000) =  ( select top(1) name  from sys.databases  where database_id > 4 );
    DECLARE @cmd nvarchar(1000);
    SET @cmd = 'ALTER DATABASE ' + @db_name + ' SET RESULT_SET_CACHING ON';
    EXEC (@cmd);
END

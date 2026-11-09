BEGIN
    PRINT 'Started creating all External Data Sources'

    -- Create all external data sources
    SELECT
        @cmd = STRING_AGG(
            CAST(
                CONCAT(
                    'IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = ',
                    QUOTENAME([eds_name], '''') COLLATE DATABASE_DEFAULT, ')',
                    ' BEGIN',
                    ' PRINT(''Creating External Data Source: ', REPLACE([eds_name], '''', '''''') COLLATE DATABASE_DEFAULT, ''');',
                    ' CREATE EXTERNAL DATA SOURCE ', QUOTENAME([eds_name]) COLLATE DATABASE_DEFAULT,
                    ' WITH (TYPE = HADOOP,',
                    ' LOCATION = ', QUOTENAME('abfss://' + REPLACE([container_name], '''', '''''') COLLATE DATABASE_DEFAULT + '@' + REPLACE([account_name], '''', '''''') COLLATE DATABASE_DEFAULT + '.dfs.core.windows.net', '''') COLLATE DATABASE_DEFAULT, ',',
                    ' CREDENTIAL = [ManagedIdentity] ); ',
                    'END'
                ) AS NVARCHAR(MAX)
            ),
            CHAR(10)
        )
    FROM [mgmt_xtinfra].[infra_workspace_storage_config];
    EXEC (@cmd);
    PRINT 'Finished creating all External Data Sources'
END

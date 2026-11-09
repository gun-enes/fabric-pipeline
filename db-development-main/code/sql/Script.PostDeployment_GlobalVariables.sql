BEGIN
    -- all JSON declarations
    DECLARE @mgmt_json NVARCHAR(MAX);
    DECLARE @core_json NVARCHAR(MAX);
    DECLARE @ext_json NVARCHAR(MAX);

    DECLARE @raw_jsonApp NVARCHAR(MAX) = N'';
    DECLARE @raw_jsonMgmt NVARCHAR(MAX) = N'$(mgmt)';
    DECLARE @raw_jsonExt NVARCHAR(MAX) = N'$(extensions)';

    DECLARE @ext_name AS NVARCHAR(20);
    DECLARE @extsCounter INT = 1;
    DECLARE @extsTotal INT;

    DECLARE @cmd NVARCHAR(MAX);

    -- no more core variable declaration after carve out
    -- BEGIN TRY
    --   SET @raw_jsonCore = N'$(core)';
    --    print (@raw_jsonCore);
    --    print ("we have a value in core_details, you are in Simplifi")
    -- END TRY
    -- --BEGIN CATCH
    --    print('[SKIPPING] Core Variable not provided');
    -- END CATCH
    -- App variable assignment in to db-deployment variable
    BEGIN TRY
        SET @raw_jsonApp = N'$(app)';
    END TRY
    BEGIN CATCH
        print('[SKIPPING] App Variable not provided');
    END CATCH

    print('RAW JSON app parameter:');
    print(@raw_jsonApp);
    print('RAW JSON mgmt parameter:');
    print(@raw_jsonMgmt);
    print('RAW JSON extensions parameter:');
    print(@raw_jsonExt);

    SET @mgmt_json = replace(@raw_jsonMgmt, '|', '"');
    SET @mgmt_json = replace(@mgmt_json, ']]', ']') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8;
    SET @core_json = replace(@raw_jsonApp, '|', '"');
    SET @core_json = replace(@core_json, ']]', ']') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8;
    SET @ext_json = replace(@raw_jsonExt, '|', '"');
    SET @ext_json = replace(@ext_json, ']]', ']') COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8;

    DECLARE @environment NVARCHAR(100);
    SELECT @environment = [environment]
    FROM OPENJSON (@mgmt_json) WITH ([environment] NVARCHAR(100) '$.environment');
    EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] 'environment', @environment;

    --set runtime mode to be used in test projects
    EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] 'runtime_mode', 'ADP'
    PRINT ('This is ADP (Base) package execution');

    DECLARE
        @order_created_minimum_seconds_between_triggers_key NVARCHAR(256) = 'order_created_minimum_seconds_between_triggers';
    IF
        NOT EXISTS (
            SELECT 1
            FROM [mgmt_xtinfra].[infra_global_config]
            WHERE [key] = @order_created_minimum_seconds_between_triggers_key
        )
        BEGIN
            PRINT @order_created_minimum_seconds_between_triggers_key
            + ' does not exist in global config, inserting a default value.';
            EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config]
                @order_created_minimum_seconds_between_triggers_key, '600'
        END

    DECLARE
        @schedule_created_minimum_seconds_between_triggers_key NVARCHAR(256) = 'schedule_created_minimum_seconds_between_triggers';
    IF
        NOT EXISTS (
            SELECT 1
            FROM [mgmt_xtinfra].[infra_global_config]
            WHERE [key] = @schedule_created_minimum_seconds_between_triggers_key
        )
        BEGIN
            PRINT @schedule_created_minimum_seconds_between_triggers_key
            + ' does not exist in global config, inserting a default value.';
            EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config]
                @schedule_created_minimum_seconds_between_triggers_key, '600'
        END

    PRINT ('Setting backup external data source global config');
    DECLARE @backup_eds NVARCHAR(128) = 'mgmt-cur' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8;
    IF (LOWER(COALESCE(JSON_VALUE(@mgmt_json, '$.is_additional_backup_storage_enabled'), 'false')) = 'true')
        BEGIN
            SET @backup_eds = 'mgmt-bck' COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8;
        END
    PRINT ('backup_external_data_source value = ' + @backup_eds);
    EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] 'backup_external_data_source', @backup_eds;
END

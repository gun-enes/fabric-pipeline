BEGIN
    PRINT 'BEGIN: Running PostDeployment script for creating default schedules';

    DECLARE @default_schedules_created_key_name NVARCHAR(100) = 'default_schedules_created'

    -- Create default schedules for SPF if they have not been created before
    IF EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_global_config]
        WHERE [key] = 'environment' AND ([value] = 'dev' OR [value] = 'tst')
    )
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM [mgmt_xtinfra].[infra_global_config]
            WHERE [key] = @default_schedules_created_key_name
        )
        BEGIN
            PRINT 'Creating default schedules'

            DECLARE @start_hour [int] = 1;
            DECLARE @stop_hour [int] = 21;
            DECLARE @day_of_month [nvarchar](100) = '*';
            DECLARE @month [nvarchar](100) = '*';
            DECLARE @days_of_week [nvarchar](100) = '1-5';
            DECLARE @priority [int] = 0;
            DECLARE @now [datetime] = GETDATE();

            EXEC [mgmt_xtinfra].[sp_infra_schedule_create] 'default_start', 'start', @start_hour, @day_of_month, @month, @days_of_week, @priority, 'mgmt_xtinfra';
            EXEC [mgmt_xtinfra].[sp_infra_schedule_create] 'default_stop', 'stop', @stop_hour, @day_of_month, @month, @days_of_week, @priority, 'mgmt_xtinfra';

            EXEC [mgmt_xtinfra].[sp_infra_upsert_global_config] @default_schedules_created_key_name, '1'
        END
    END
    PRINT 'END: Running PostDeployment script for creating default schedules';
END

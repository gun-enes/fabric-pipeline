CREATE PROCEDURE [UnitTests].[sp_testutil_verify_gatherstats_schedule]
(
    @workspace NVARCHAR(100)
)
AS
BEGIN

    PRINT('Verifying deletion of gatherstats schedules for workspace: ' + @workspace);

    DECLARE @is_spf NVARCHAR(2);
    SELECT @is_spf = MAX(CASE WHEN [KeyName] = 'is_spf' THEN [Value] END)
    FROM [UnitTests].[KeyValueStore];

    SELECT * INTO [#related_schemas] FROM (
        SELECT DISTINCT [destination_schema_name] AS [schema_name]
        FROM [mgmt_xtinfra].[infra_orders_details_schemalinks]
        WHERE [source_schema_name] = @workspace
    ) AS [rs];

    IF @is_spf = '1'
    BEGIN
        INSERT INTO [#related_schemas]
        SELECT @workspace + '_' + [schema_name]
        FROM [mgmt_xtinfra].[infra_static_ext_schemas]
    END

    SELECT * INTO [#related_schedules] FROM (
        SELECT DISTINCT [infra_schedule_key]
        FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
        WHERE [schema_name] IN (SELECT [schema_name] FROM [#related_schemas])
    ) AS [rs];

    -- Verify remaining [infra_schedule] entries are not related to workspace
    DECLARE @remaining_schedules NVARCHAR(MAX);
    SELECT @remaining_schedules = STRING_AGG([key], ', ')
    FROM [mgmt_xtinfra].[infra_schedule]
    WHERE [key] IN (SELECT [infra_schedule_key] FROM [#related_schedules]);
    IF @remaining_schedules IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected rows found in [infra_schedule]:', @remaining_schedules);
    END;

    -- Verify remaining [infra_expanded_schedule] entries are not related to workspace
    DECLARE @remaining_expanded NVARCHAR(MAX);
    SELECT @remaining_expanded = STRING_AGG([key], ', ')
    FROM [mgmt_xtinfra].[infra_expanded_schedule]
    WHERE [key] IN (SELECT [infra_schedule_key] FROM [#related_schedules]);
    IF @remaining_expanded IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected rows found in [infra_expanded_schedule]:', @remaining_expanded);
    END;

    -- Verify remaining [infra_gatherstats_schedule_detail] entries are not related to workspace
    DECLARE @remaining_details NVARCHAR(MAX);
    SELECT @remaining_details = STRING_AGG([schema_name], ', ')
    FROM [mgmt_xtinfra].[infra_gatherstats_schedule_detail]
    WHERE [schema_name] IN (SELECT [schema_name] FROM [#related_schemas]);
    IF @remaining_details IS NOT NULL
    BEGIN
        INSERT INTO [UnitTests].[Errors] ([VerificationError], [Value])
        VALUES ('Unexpected rows found in [infra_gatherstats_schedule_detail]:', @remaining_details);
    END;

    IF (OBJECT_ID('tempdb..[#related_schemas]') IS NOT NULL)
        DROP TABLE [#related_schemas];
    IF (OBJECT_ID('tempdb..[#related_schedules]') IS NOT NULL)
        DROP TABLE [#related_schedules];

    PRINT('Gatherstats schedule deletion verification completed for workspace: ' + @workspace);
END
GO

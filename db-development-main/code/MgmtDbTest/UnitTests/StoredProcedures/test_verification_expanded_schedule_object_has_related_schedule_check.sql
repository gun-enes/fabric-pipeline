--Check if all expanded schedules have a corresponding schedule
CREATE PROCEDURE [UnitTests].[test_verification_expanded_schedule_object_has_related_schedule_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_expanded_schedule_object_has_related_schedule_check')
    SELECT DISTINCT *
    INTO [UnitTests].[ExpandedSchedulesWithoutSchedule]
    FROM [mgmt_xtinfra].[infra_expanded_schedule]
    WHERE [key] NOT IN (
        SELECT [key] FROM [mgmt_xtinfra].[infra_schedule]
    )

    PRINT ('Expanded schedules that do not have schedule are given below')
    -- Table should be empty if all expanded schedules has corresponding schedule with same key
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.ExpandedSchedulesWithoutSchedule'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_expanded_schedule_object_has_related_schedule_check]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_expanded_schedule_object_has_related_schedule_check')
    DROP TABLE [UnitTests].[ExpandedSchedulesWithoutSchedule]
END;
GO

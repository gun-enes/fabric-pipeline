--Check if self service orders are older than an hour and not processed
CREATE PROCEDURE [UnitTests].[test_verification_ss_infra_orders_master_orders_processed_check]
AS
BEGIN
    PRINT ('Executing Test: test_verification_ss_infra_orders_master_orders_processed_check')
    SELECT *
    INTO [UnitTests].[UnprocessedOrders]
    FROM [mgmt_xtinfra].[infra_orders_master]
    WHERE [status] = 'pending'
    OR [status] = 'new'
    AND GETDATE() > DATEADD(hour, 1, [order_date])

    PRINT ('Self-service orders that are not processed within 1 hour are given below')
    -- Table should be empty if all orders are processed within 1 hour
    EXEC [tSQLt_synapse].[AssertEmptyTable] 'UnitTests.UnprocessedOrders'
END;
GO

CREATE PROCEDURE [UnitTests].[rollback_test_verification_ss_infra_orders_master_orders_processed_check]
AS
BEGIN
    PRINT ('Executing Rollback: rollback_test_verification_ss_infra_orders_master_orders_processed_check')
    DROP TABLE [UnitTests].[UnprocessedOrders]
END;
GO

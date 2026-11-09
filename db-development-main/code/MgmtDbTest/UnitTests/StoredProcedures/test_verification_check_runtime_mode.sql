--Check if runtime mode is set correctly
CREATE PROCEDURE [UnitTests].[test_verification_check_runtime_mode]
AS
BEGIN
    PRINT ('Executing Test: test_verification_check_runtime_mode')
    DECLARE @runtime_mode NVARCHAR(3) = '---';

    SELECT @runtime_mode = [value]
    FROM [mgmt_xtinfra].[infra_global_config]
    WHERE [key] = 'runtime_mode'

    -- To check if runtime mode is defined
    EXEC [tSQLt_synapse].[AssertNotEqualsString] '---', @runtime_mode;

    IF EXISTS (
        SELECT 1
        FROM [sys].[schemas]
        WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'spf_core'
    )
    BEGIN
        PRINT ('Runtime mode should be SPF')
        EXEC [tSQLt_synapse].[AssertEqualsString] 'SPF', @runtime_mode;
    END

    IF EXISTS (
        SELECT 1
        FROM [sys].[schemas]
        WHERE [name] COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 = 'tdp_core'
    )
    BEGIN
        PRINT ('Runtime mode should be ADP')
        EXEC [tSQLt_synapse].[AssertEqualsString] 'ADP', @runtime_mode;
    END
END;
GO

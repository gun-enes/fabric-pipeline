/*
Description:
This stored procedure is used collect SQL users from master DB and save it in SQLPool for password age validation

Author:
jyothish.b@allianz.com
*/
CREATE PROCEDURE [mgmt_xtinfra].[infra_sqluser_passwordaudit]
    @PrincipalID        INT,
    @LocalUserName      NVARCHAR(128),
    @DateOfCreation     DATETIME2,
    @DateOfLastModified DATETIME2,
    @PasswordAgeDays    INT
AS
BEGIN
    DECLARE @Now DATETIME2 = SYSUTCDATETIME();

    -- Determine the incoming status (Active or GracePeriod) based on password age.
    DECLARE @IncomingStatus NVARCHAR(30) =
        CASE WHEN @PasswordAgeDays >= 180 THEN 'GracePeriod' ELSE 'Active' END;

    IF EXISTS (
        SELECT 1
        FROM [mgmt_xtinfra].[infra_sqluser_password_master]
        WHERE PrincipalID   = @PrincipalID
          AND LocalUserName = @LocalUserName
    )
    BEGIN
        -- Update existing row; sticky statuses (GracePeriodAndNotified, Disabled)
        -- are never overwritten by fresh login data from the workflow.
        UPDATE [mgmt_xtinfra].[infra_sqluser_password_master]
        SET
            DateOfLastModified = @DateOfLastModified,
            PasswordAgeDays    = @PasswordAgeDays,
            PasswordStatus     = CASE
                                     WHEN PasswordStatus IN ('GracePeriodAndNotified', 'Disabled')
                                         THEN PasswordStatus
                                     ELSE @IncomingStatus
                                 END,
            CollectionDate     = @Now
        WHERE PrincipalID   = @PrincipalID
          AND LocalUserName = @LocalUserName;
    END
    ELSE
    BEGIN
        -- Insert new login not yet tracked.
        INSERT INTO [mgmt_xtinfra].[infra_sqluser_password_master]
        (
            PrincipalID,
            LocalUserName,
            DateOfCreation,
            DateOfLastModified,
            PasswordAgeDays,
            PasswordStatus,
            CollectionDate
        )
        VALUES
        (
            @PrincipalID,
            @LocalUserName,
            @DateOfCreation,
            @DateOfLastModified,
            @PasswordAgeDays,
            @IncomingStatus,
            @Now
        );
    END
END;
GO

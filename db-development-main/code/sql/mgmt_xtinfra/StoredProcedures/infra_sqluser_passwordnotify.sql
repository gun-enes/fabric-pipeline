/*
Description:
This stored procedure is used notify customers to change the SQL User password older than 180 days

Author:
jyothish.b@allianz.com
*/
CREATE PROCEDURE [mgmt_xtinfra].[infra_sqluser_passwordnotify]
    @UserName NVARCHAR(128),
    @EmailId  NVARCHAR(500)
AS
BEGIN
    -- Called by GitHub Actions after notification email is confirmed delivered.
    -- Advances status to GracePeriodAndNotified and stamps NotificationDate —
    -- the 31-day SR window starts from this date.
    UPDATE [mgmt_xtinfra].[infra_sqluser_password_master]
    SET
        PasswordStatus   = 'GracePeriodAndNotified',
        NotificationDate = SYSUTCDATETIME(),
        EmailId          = @EmailId
    WHERE LocalUserName  = @UserName
      AND PasswordStatus = 'GracePeriod';
END;
GO

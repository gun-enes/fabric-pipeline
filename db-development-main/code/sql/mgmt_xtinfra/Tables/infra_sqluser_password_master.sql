CREATE TABLE [mgmt_xtinfra].[infra_sqluser_password_master]
(
    PrincipalID        INT              NOT NULL,
    LocalUserName      NVARCHAR(128)    COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    DateOfCreation     DATETIME2        NOT NULL,
    DateOfLastModified DATETIME2        NOT NULL,
    PasswordAgeDays    INT              NOT NULL,
    PasswordStatus     NVARCHAR(30)     COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NOT NULL,
    CollectionDate     DATETIME2        NOT NULL,
    NotificationDate   DATETIME2        NULL,
    EmailId            NVARCHAR(500)    COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8 NULL
) WITH ( DISTRIBUTION = REPLICATE, CLUSTERED INDEX (PrincipalID) );
GO

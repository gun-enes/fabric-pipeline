CREATE procedure mgmt_xtinfra.sp_infra_privs_check
  /* Scope  : sync schema reader and writer roles for login user
 * Project  : Simplfi
 * Activity : Dedicated SQL pool deployment
 * Author   : jyothish.b@allianz.com
 */
  (
    @PRIVS_TYPE varchar(100),
    @OBJECT_NAME varchar(100)
  )
AS
BEGIN
  IF (@PRIVS_TYPE = 'SCHEMA')
begin
    select
      perm.state_desc COLLATE DATABASE_DEFAULT + ' ' + perm.permission_name COLLATE DATABASE_DEFAULT + ' ON SCHEMA::[' + SCHEMA_NAME(major_id) COLLATE DATABASE_DEFAULT + '] TO [' + users.name COLLATE DATABASE_DEFAULT + ']',
      SCHEMA_NAME(major_id)
    from
      sys.database_permissions perm
      inner join sys.database_principals users
      on
	perm.grantee_principal_id = users.principal_id
    where
	perm.class = 3
      and SCHEMA_NAME(major_id)= @OBJECT_NAME;
  end
ELSE IF (@PRIVS_TYPE = 'ROLE')
begin
    select
      princ.name COLLATE DATABASE_DEFAULT,
      princ.type_desc COLLATE DATABASE_DEFAULT,
      perm.permission_name COLLATE DATABASE_DEFAULT,
      perm.state_desc COLLATE DATABASE_DEFAULT,
      perm.class_desc COLLATE DATABASE_DEFAULT,
      SCHEMA_NAME(major_id) COLLATE DATABASE_DEFAULT
    from
      sys.database_principals princ
      left join sys.database_permissions perm
      on
	perm.grantee_principal_id = princ.principal_id
    where
	princ.type_desc = 'DATABASE_ROLE'
      and
      princ.name COLLATE DATABASE_DEFAULT = @OBJECT_NAME;
  end
ELSE IF (@PRIVS_TYPE = 'USER')
begin
SELECT
	   pr.name COLLATE DATABASE_DEFAULT AS [Role_or_Privilege_Name],
	   'EXEC sp_addrolemember [' + pr.name COLLATE DATABASE_DEFAULT + '],[' + members.name COLLATE DATABASE_DEFAULT + ']' AS [PRIVS_CMD_INFO],
	   pr.type_desc COLLATE DATABASE_DEFAULT AS 'PRIVS_TYPE' ,
	   database_role_members.member_principal_id AS MemberPrincipalID,
	   members.name COLLATE DATABASE_DEFAULT AS MemberPrincipalName,members.type_desc COLLATE DATABASE_DEFAULT as USER_TYPE,members.authentication_type_desc COLLATE DATABASE_DEFAULT AS AUTHENTICATION_TYPE
    FROM
	   sys.database_role_members AS database_role_members
       JOIN sys.database_principals AS pr
       ON
	   database_role_members.role_principal_id  =  pr.principal_id
       JOIN sys.database_principals AS members
       ON
	   database_role_members.member_principal_id  = members.principal_id
	   and members.name COLLATE DATABASE_DEFAULT = @OBJECT_NAME
	   UNION
 SELECT
       pe.permission_name COLLATE DATABASE_DEFAULT AS [Role_or_Privilege_Name],
       pe.state_desc COLLATE DATABASE_DEFAULT + ' ' + pe.permission_name COLLATE DATABASE_DEFAULT + ' TO [' + pr.name COLLATE DATABASE_DEFAULT + ']' AS [PRIVS_CMD_INFO],
       'DATABASE_PRIVILEGE' AS [PRIVS_TYPE] ,
       pr.principal_id  AS [MemberPrincipalID],
       pr.name COLLATE DATABASE_DEFAULT AS [MemberPrincipalName] ,
       pr.type_desc COLLATE DATABASE_DEFAULT as [USER_TYPE],
       pr.authentication_type_desc COLLATE DATABASE_DEFAULT AS [AUTHENTICATION_TYPE]
   FROM sys.database_principals AS pr
       JOIN sys.database_permissions AS pe
       ON pe.grantee_principal_id  = pr.principal_id  and pr.type_desc COLLATE DATABASE_DEFAULT in ('EXTERNAL_USER','EXTERNAL_GROUP','SQL_USER')
       and pr.name COLLATE DATABASE_DEFAULT = @OBJECT_NAME;
  end
ELSE
begin
    print 'Please check the syntax again and retry'
  end
END

--********************************************************************************************************
-- Author*:			Dan Dapper
-- Creation Date:	July 26, 2013
-- Updated By:		Amit Patel
-- Updated Date:	July 26, 2013
-- Rave Version Developed For*: 5.6.x, 201x.x.x.x
--********************************************************************************************************

--********************************************************************************************************
-- Description*: DB initialize script that will disable emails, enable defuser, allow multiple logs, remove
-- password timesouts, give all user groups access to Configuration & UA modules, assign account to most 
-- access module
--
-- Keywords: DB Cleanup
--********************************************************************************************************
BEGIN TRY
Declare @Login varchar(100)
Declare @error tinyint
Declare @errorMessage varchar(max)

Set @Login = 'defuser' --Account that will be altered for access
Set @error = 0

-- Change an account to be accesible. Set the password & PIN to 'password'
update users
set	lockedOut = 0,
	enabled = 1,
	useractive = 1,
	password = '5F4DCC3B5AA765D61D8327DEB882CF99', --password
	PIN = '5F4DCC3B5AA765D61D8327DEB882CF99', --password
	trained = '2010-01-01 00:00:00.000',
	ISTRAININGONLY = 0,
	trainingsigned = 1,
    useoldpassword=1,
	isclinicaluser = 1,
	Salt = null
where login = @login  --specify an account to hack

-- assign to Administrative user group
update Users 
set UserGroup = (
	select max(UserGroupID) 
	from UserGroups
	where Permissions = (
		select max(Permissions) 
		from UserGroups
	)
)
where Login = @login

-- prevent email from being sent out
update configuration set configvalue = '' where tag = 'MailServerName'
update configuration set configvalue = 'true' where tag = 'DisableSendingEmails'
update configuration set configvalue = 'false' where tag = 'EnableEmailAlertFunctionality'

-- attempt to get rid of the user timeouts (FAIL)
delete from configuration where tag in ('InteractionTimeout','PasswordTimeout')

-- allow login via multiple tabs
update configuration set configvalue= 'True' where tag = 'AllowMultipleLogins'

-- give all user groups access to Configuration, User Administration
insert into usermodules (moduleid,usergroupid)
select distinct moduleid, usergroup
from installedmodules im
cross join users u
where modulename in ('CONG','UADM')
	and not exists (select null 
		from usermodules um 
		where 
			um.moduleid = im.moduleid 
			and um.usergroupid = u.usergroup
)

-- for report access
If Not Exists (Select u.name from sysusers u where name = N'prodsupport_rpt')
BEGIN
	EXEC sp_grantdbaccess 'prodsupport_rpt'
END


EXEC sp_addrolemember 'Rave_Reporter', 'prodsupport_rpt'
EXEC sp_addrolemember 'db_datareader', 'prodsupport_rpt'
EXEC sp_addrolemember 'db_denydatawriter', 'prodsupport_rpt'

END TRY

BEGIN CATCH
	SET @error = 1
	set @errorMessage = ERROR_MESSAGE() + char(10) + 'Error in script execution, please review.'
	RAISERROR (@errorMessage, 16, 2) WITH SETERROR
END CATCH

IF (@error = 0)
BEGIN
	PRINT N'DB Initialization Script Executed:';
	PRINT N'   ' + @login + ' Password & PIN# set to password';
	PRINT N'   ' + @login + ' Assigned User Group with max permissions';
	PRINT N'   All user groups set to to have User Admin & Config Access';
	PRINT N'   Multiple logins enabled';
	PRINT N'   Email server disabled, email server set to blank';
	PRINT N'   Timeout settings removed';
	PRINT N'   Report access granted to necessary DB user (reporting must be setup)';
END
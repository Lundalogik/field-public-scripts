# (c) RemoteX Technologies AB, 2008. All rights reserved.
# * This script creates a server login and a database user (mapped to the
#   server login). The user is then assigned a role in the database.
# -----------------------------------------------------------------------------
param(
	$Server,
	$Database,
	$Username,
	$Password,
	$DbUsername,
	$DbPassword,
	$DbRole
)
$ScriptDir = $MyInvocation.MyCommand.Path | split-path
. $ScriptDir\Sql.ps1 
$SqlConnection = DbConnect $Server $Database $Username $Password
$sql = @"
IF NOT EXISTS ( SELECT * FROM master.dbo.syslogins WHERE loginname = '{1}' )
	BEGIN
		CREATE LOGIN {1} WITH
			PASSWORD = '{2}',
			CHECK_POLICY = OFF
	END
GO
USE {0}
IF  EXISTS (SELECT * FROM sys.database_principals WHERE name = N'{1}')
DROP USER [{1}]
GO
USE {0}
IF NOT EXISTS ( select * from sys.database_principals p inner join sys.syslogins l on l.sid = p.sid where l.name = '{1}' )
	BEGIN
		CREATE USER {1} FOR LOGIN {1}
	END
GO


EXEC sp_addrolemember '{3}', '{1}'
GO
"@ -f $Database, $DbUsername, $DbPassword, $DbRole

try {
	ExecuteScript $SqlConnection $sql
} finally {
	$SqlConnection.Dispose()
}

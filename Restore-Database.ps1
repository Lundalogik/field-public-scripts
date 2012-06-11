#Requires -Version 2.0 
[CmdletBinding(SupportsShouldProcess=$true)] 
param(
	[parameter(mandatory=$true)]
	[string] $server,
	[parameter(mandatory=$true)]
	[string] $database,
	[parameter(mandatory=$true)]
	[string] $username,
	[parameter(mandatory=$true)]
	[string] $password,
	[parameter(mandatory=$true)]
	[string] $backupFilePath,
	[parameter(mandatory=$false)]
	[hashtable] $datafilesWithMove,
	[switch] $noCreate
)

$ScriptDir = $MyInvocation.MyCommand.Path | split-path
. $ScriptDir\Sql.ps1 

if( ! $noCreate ) {
	$SqlConnection = DbConnect $Server $null $Username $Password
	try {
		write-host "Creating database, please wait..."
		$createDbSql = @"
			CREATE DATABASE $database
			ALTER DATABASE $database SET ALLOW_SNAPSHOT_ISOLATION ON
			ALTER DATABASE $database SET READ_COMMITTED_SNAPSHOT ON
			ALTER DATABASE $database SET COMPATIBILITY_LEVEL = 100
"@
			$null = ExecuteNonQuery $SqlConnection $createDbSql
	} finally {
		$SqlConnection.Dispose()
	}
}

Write-Host "Restoring database $database on server $server from $backupFilePath"
try
{
	$SqlConnection = DbConnect $server "master" $username $password 
	try {
		$null = ExecuteNonQuery $SqlConnection "ALTER DATABASE $database SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
		$restoreCommand = "RESTORE DATABASE $database FROM DISK='$backupFilePath' WITH REPLACE"
		if( $datafilesWithMove ) {
			$datafilesWithMove.Keys | %{ 
				$restoreCommand += ",MOVE '$_' TO '$($datafilesWithMove[$_])'"
			}
		}
		$null = ExecuteNonQuery $SqlConnection $restoreCommand
		$null = ExecuteNonQuery $SqlConnection "ALTER DATABASE $database SET MULTI_USER"
	} finally {
		$SqlConnection.Dispose()
	}
}
catch 
{
	throw "Database restore failed! $_"
}
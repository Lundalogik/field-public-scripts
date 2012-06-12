param(
	[parameter(mandatory=$true)]
	[string] $server,
	[parameter(mandatory=$true)]
	[string] $database,
	[string] $username,
	[string] $password,
	[string[]] $readers,
	[string[]] $writers,
	[string[]] $owners,
	[string] $defaultSchema = 'dbo',
	[switch] $force
)
$ScriptDir = $MyInvocation.MyCommand.Path | split-path
. $ScriptDir\Sql.ps1 

$rolemap = @{}
function addRoleMap( $user, $role ) { 
	if( !$rolemap.ContainsKey( $user ) ) {
		$rolemap.Add( $user, @( $role ) )
	} elseif( $rolemap[$user] -notcontains $role ) {
		$rolemap[$user] = $rolemap[$user] + $role
	}
}
$readers | %{ addRoleMap $_ 'db_datareader' }
$writers | %{ addRoleMap $_ 'db_datawriter' }
$owners | %{ addRoleMap $_ 'db_owner' }

$Sql = ""
$rolemap.Keys | %{ 
	$userKey = $_
	$Sql += @"
USE [$Database]
GO
IF  EXISTS (SELECT * FROM sys.database_principals WHERE name = N'$userKey')
DROP USER [$userKey]
GO
USE [$Database]
GO
CREATE USER [$userKey] FOR LOGIN [$userKey] WITH DEFAULT_SCHEMA=[$defaultSchema]
GO`r`n
"@
	$rolemap[$userKey] | %{ $Sql += "EXEC sp_addrolemember N'$_', N'$userKey'`r`nGO`r`n" }
}

Write-Host "Generated SQL:"
$Sql | oh

if($force ) {
	Write-Host "Executing command..."
	try {
		$SqlConnection = DbConnect $Server $Database $Username $Password
		$null = ExecuteScript $SqlConnection $Sql
		Write-Host "Done."
	} finally {
		if( $SqlConnection -ne $null ) {
			$SqlConnection.Dispose()
		}
	}
} else {
	Write-Host "You must specify -Force to actually send the command to the SQL server"
}

function ExecuteScript() {
	param(
		[parameter(mandatory=$true)]
	 	[System.Data.SqlClient.SqlConnection]$SqlConnection, 
		[parameter(mandatory=$true)]
		$sqlScript, 
		[hashtable]$variables = $NULL)

	if( test-path $sqlScript -erroraction SilentlyContinue ) {
		$sqlScriptFile = $sqlScript
		$lines = Get-Content $sqlScript
	} else {
		$sqlScriptFile = "unknown"
		$lines = $sqlScript.Split( "`r`n" )
	}
	$lines += "GO"
	$Query = ""
	$batchNumber = 0
	$batchLines = 0
	for ( $lineNumber = 0; $lineNumber -lt $lines.Length; $lineNumber++ ) {
		if( $lines[$lineNumber] -match '^\s*GO\s*$' ) {
			$batchNumber++
			$Query = EvaluateSqlScriptVariables $Query $variables
			$Query = $Query.Trim()
			if( $Query.Length -eq 0 ) {
				continue
			}
			
			try {
				$null = ExecuteNonQuery $SqlConnection $Query
			} catch {
				$msg = New-Object "System.Text.StringBuilder"
				$null = $msg.AppendLine( "Error executing batch #" + $batchNumber + ": " + $_ )
				$null = $msg.AppendLine( "At " + $sqlScriptFile + ":" + ($lineNumber - $batchLines + 1) + " to " + $lineNumber )
				$null = $msg.AppendLine( "===BATCH START===" )
				$null = $msg.AppendLine( $Query )
				$null = $msg.AppendLine( "===BATCH END===" )
				throw $msg.ToString()
			}
			
			$Query = ""
			$batchLines = 0
			continue
		}
		$Query += $lines[$lineNumber]
		$Query += [Environment]::NewLine
		$batchLines++
	}
}

function EvaluateSqlScriptVariables( [string]$sqlScriptText, [hashtable]$variables = $NULL )
{
	if( !$variables -or $variables.Count -eq 0 ) { return $sqlScriptText }
	
	if ($variables -and $variables.Count -gt 0) {
		foreach($key in $variables.keys) {
			$val = $variables[$key]
			Write-Debug "Evaluating \$\($key\) to $val"
			$sqlScriptText = $sqlScriptText -replace "\$\($key\)", $val
		}
	}
	
	return $sqlScriptText
}

function ExecuteNonQuery( $SqlConnection, $CommandText )
{
	$SqlCommand = DbCommand $SqlConnection $CommandText
	try {
		try {
			return $SqlCommand.ExecuteNonQuery()
		} catch {
				$msg = New-Object "System.Text.StringBuilder"
				$null = $msg.AppendLine( "Error executing sql: " + $_	 )
				$null = $msg.AppendLine( "===BATCH START===" )
				$null = $msg.AppendLine( $CommandText )
				$null = $msg.AppendLine( "===BATCH END===" )
				throw $msg.ToString()
		}
	} finally {
		$SqlCommand.Dispose()
	}
}

function ExecuteScalar( $SqlConnection, $CommandText )
{
	$SqlCommand = DbCommand $SqlConnection $CommandText
	try {
		return $SqlCommand.ExecuteScalar()
	} finally {
		$SqlCommand.Dispose()
	}
}

function ExecuteTable( $SqlConnection, $CommandText )
{
	$cmd = DbCommand $SqlConnection $CommandText
	try {  
		$adapter = new-object System.Data.SqlClient.SqlDataAdapter
		$adapter.SelectCommand = $cmd
		$ds = new-object System.Data.DataSet
		$rows = $adapter.Fill( $ds )
		return $ds.Tables[0]
	} finally {
		$cmd.Dispose()
	}
}

function DbExists( [string]$Server='(local)', [string]$Database, [string]$Username = $NULL, [string]$Password = $NULL )
{
	$conn = DbConnect $server "master" $username $password
	try { 
		$compatlevel = ExecuteScalar $conn "SELECT compatibility_level FROM sys.databases WHERE name = '$Database'"
		if( $compatlevel -ne $null ) {
			Write-Verbose "Database $database exists on server $server ( compat level = $compatlevel )"
			return $true
		} else { return $false }
	} finally {
		$conn.Dispose()
	}
}

function DbConnect( [string]$Server='(local)', [string]$Database='master', [string]$Username = $NULL, [string]$Password = $NULL )
{
	if( [String]::IsNullOrEmpty( $Database ) ) {
		$Database = "master"
	}

	# handles the InfoMessage event so we can print any status
	# information back out to the screen
	$SqlConnection_InfoMessage = [System.Data.SqlClient.SqlInfoMessageEventHandler]{
		foreach ( $SqlError in $_.Errors ) {
			if ( $SqlError.Class -eq 0 ) {
				Write-Host $SqlError.Message
			} else {
				Write-Warning $SqlError.Message + ($SqlError | select * -ex Message | Out-String)
			}
		}
	}
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = BuildConnectionString $Server $Database $Username $Password
    Write-Verbose "Using connection string '$($SqlConnection.ConnectionString)'"
	$SqlConnection.add_InfoMessage($SqlConnection_InfoMessage)
	try {
		$SqlConnection.Open()
	} catch {
		throw "Failed to open SQL connection to '$server', database '$database': $_"
	}

	return $SqlConnection
}

function DbCommand( $SqlConnection = $(throw "Not a valid connection"), $CommandText )
{
    if( $SqlConnection -eq $null )
    {
        throw "Invalid connection. Connection is null"
    }

    if( [String]::IsNullOrEmpty( $CommandText ) )
    {
        throw "Command text is null or empty"
    }

	$SqlCommand = New-Object System.Data.SqlClient.SqlCommand
	$SqlCommand.Connection = $SqlConnection
	# 30 min timeout required for long running commands such as BACKUP DATABASE
	$SqlCommand.CommandTimeout = 1800
	$SqlCommand.CommandText = $CommandText
	$SqlCommand.CommandType = 'Text'
    
    Write-Verbose "Creating command for: $CommandText"

	return $SqlCommand
}

function BuildConnectionString( $server, $database, $username, $password )
{
	if( [String]::IsNullOrEmpty( $Username ) -or $Password -eq $NULL ) {
		return "Server=$server;Database=$database;Trusted_Connection=True;"
	} else {
		return "Server=$Server;Database=$database;UID=$Username;PWD=$Password"
	}
}

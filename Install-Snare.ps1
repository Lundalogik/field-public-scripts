<#
.SYNOPSIS
	Script to remotely install Snare on a group of boxes using Powershell and WinRM.
.DESCRIPTION
	Port of rsnare.bat originally written by Steven Chase at Verizon Select Services.
	
	Uses binaries found at the default or any given location.
	Target installation directory is SystemRoot\Snare.
	
.PARAMETER Session
	The WinRM session used to deploy
.PARAMETER SnareDestination
	The destination syslog server
.PARAMETER SnarePassword
	The password for the web server (string or securestring)
.PARAMETER TargetDirectory
	Optional target directory. Defaults to SystemRoot\Snare
.PARAMETER BinariesDir
	Optional source directory for the binaries. Defaults to Program Files\Snare.
#>
param(
	[parameter(mandatory=$true, valuefrompipelinebypropertyname=$true)]
	[System.Management.Automation.Runspaces.PSSession] $Session,
	[parameter(valuefrompipelinebypropertyname=$true)]
	[string] $SnareDestination = "127.0.0.1",
	[parameter(mandatory=$true, valuefrompipelinebypropertyname=$true)]
	$SnarePassword,
	[parameter(valuefrompipelinebypropertyname=$true)]
	[string] $TargetDirectory,
	$BinariesDir = $( $env:ProgramFiles, ${env:ProgramFiles(x86)} | ls -Filter Snare | select -First 1 -ExpandProperty FullName )
)
begin {
	$ScriptDir = $MyInvocation.MyCommand.Path | split-path
	Set-Alias sendFile $ScriptDir\Send-File.ps1
	$filesToCopy = ls $BinariesDir | select -ExpandProperty FullName
	function RemoteInstallScript() {
		{ 
			param( $TargetDirectory, $SnareDestination, $SnareAccessKeySet, $SnareAccessKeySet1, $SnareAccessKeySet2, $SnareAccessKeySet3 )
			if( !$TargetDirectory ) {
				$TargetDirectory = $env:SystemRoot
			}
			$InstallDir = Join-Path $TargetDirectory "Snare"
			if( !( test-path $InstallDir ) ) {
				mkdir $InstallDir | Out-Null
			}

			# Credit: http://pssccm.blogspot.se/2012/06/powershell-set-registry-key.html
			Function New-RegistryKey([string]$key,[string]$Name,[string]$type,[string]$value)
			{
				#Split the registry path into its single keys and save
				#them in an array, use \ as delimiter:
				$subkeys = $key.split("\")

				#Do this for all elements in the array:
				foreach ($subkey in $subkeys)
				{
					#Extend $currentkey with the current element of
					#the array:
					$currentkey += ($subkey + '\')

					#Check if $currentkey already exists in the registry
					if (!(Test-Path $currentkey))
					{
						#If no, create it and send Powershell output
						#to null (don't show it)
						New-Item -Type String $currentkey | Out-Null
					}
				 }
				 #Set (or change if alreday exists) the value for $currentkey
				 Set-ItemProperty $CurrentKey $Name -value $Value -type $type 
			}
			function regAdd( $key, $values ) {
				$values | %{
					New-RegistryKey -Key $key -Type $_[0] -Name $_[1] -Value $_[2]
				}
			}
			
			Write-Host "Writing registry settings..."

			regAdd -key "HKLM:\Software\InterSect Alliance\AuditService\Config" `
					-values @( `
						@( "DWORD", 	"Audit", 			0 ), 
						@( "DWORD", 	"Checksum", 		0 ), 
						@( "DWORD", 	"CritAudit", 		0 ), 
						@( "DWORD", 	"FileAudit", 		0 ), 
						@( "DWORD", 	"FileExport", 		0 ), 
						@( "DWORD", 	"Heartbeat", 		0 ), 
						@( "DWORD", 	"EnableUSB", 		0 ), 
						@( "DWORD", 	"AgentLog", 		0 ), 
						@( "DWORD", 	"ClearTabs", 		0 ), 
						@( "DWORD", 	"LeaveRetention", 	0 ), 
						@( "String",	"Clientname", 		$null ), 
						@( "String", 	"Delimiter", 		"`t" ), 
						@( "String", 	"OutputFilePath", 	"" ) )
				
			regAdd -key "HKLM:\Software\InterSect Alliance\AuditService\Network" `
					-values @( `
						@( "String", 	"Destination", 	$SnareDestination ),
						@( "DWORD", 	"DestPort", 	6161 ), 
						@( "DWORD", 	"Syslog", 		0 ), 
						@( "DWORD", 	"SyslogDest", 	13 ) )
				
			regAdd -key "HKLM:\Software\InterSect Alliance\AuditService\Objective" `
					-values @( `
						@( "String", 	"Objective0", 	"1    31    32    Logon_Logoff    ***    0    *" ),
						@( "String", 	"Objective1", 	"0    31    32    Process_Events    ***    0    *" ),
						@( "String", 	"Objective2", 	"2    31    32    User_Group_Management_Events    ***    0    *" ),
						@( "String", 	"Objective3", 	"24    32    Reboot_Events    ***    0    *" ),
						@( "String", 	"Objective4", 	"3    31    32    Security_Policy_Events    ***    0    *" ),
						@( "String", 	"Objective5", 	"1    31    95    *    ***    0    *" ) )
				
			regAdd -key "HKLM:\Software\InterSect Alliance\AuditService\Remote" `
					-values @( `
						@( "DWORD", 	"AccessKey", 	1 ),
						@( "String", 	"AccessKeySet", $SnareAccessKeySet ), 
						@( "String", 	"AccessKeySetSnare1", $SnareAccessKeySet1 ), 
						@( "String", 	"AccessKeySetSnare2", $SnareAccessKeySet2 ), 
						@( "String", 	"AccessKeySetSnare3", $SnareAccessKeySet3 ), 
						@( "DWORD", 	"Allow", 		1 ), 
						@( "DWORD", 	"AllowBasicAuth", 1 ), 
						@( "DWORD", 	"EnableCookies", 1 ), 
						@( "DWORD", 	"Restrict", 	0 ),
						@( "String", 	"RestrictIP", 	"127.0.0.1" ),
						@( "DWORD", 	"WebPort", 		6161 ),
						@( "DWORD", 	"WebPortChange", 0 ) )
				
			regAdd -key "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Snare_is1" `
					-values @( `
						@( "String", 	"DisplayIcon", 				$( Join-Path $InstallDir "s_32.ico" ) ), 
						@( "String", 	"DisplayName", 				"Snare version 4.0.2.1" ), 
						@( "String", 	"DisplayVersion", 			"4.0.2.1" ),
						@( "String", 	"Inno Setup: App Path", 	$InstallDir ),
						@( "String", 	"Inno Setup: Icon Group", 	"InterSect Alliance" ),
						@( "String", 	"Inno Setup: Setup Version","1.3.24" ),
						@( "String", 	"Inno Setup: User", 		"local" ),
						@( "String", 	"Publisher", 				"InterSect Alliance Pty Ltd" ),
						@( "String", 	"UninstallString", 			$( Join-Path $InstallDir "unins000.exe" ) ), 
						@( "String", 	"URLInfoAbout", 			"http://www.intersectalliance.com/" ) ) 

			# Configure the eventlog to overwrite as required, and only keep 512k of data
			"Security", "System", "Application" | %{
				Write-Host "Configuring retention and max size for event log $_"
				regAdd -key "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\$_" `
						-values @( `
							@( "DWORD", 	"MaxSize", 		512 ), 
							@( "DWORD", 	"Retention", 	0 ) )
			}
			
			$svc = gwmi win32_service -filter "name='SNARE'"
			if( $svc ) { 
				$svc.StopService() | Out-Null
				$svc.Delete() | Out-Null
				Write-Host -NoNewline "Waiting for service to be deleted..."
				while( gwmi win32_service -filter "name='SNARE'" ) {
					Write-Host -NoNewline "."
					sleep -Seconds 2
				}
				Write-Host "Ok"
			}
			Write-Host "Creating service..."
			New-Service -BinaryPathName $(Join-Path $InstallDir "SnareCore.exe") `
						-DisplayName "SNARE" `
						-Name "SNARE" `
						-StartupType Automatic | Out-Null
			return $InstallDir
		}
	}

	filter MD5 {
		$md5 = new-object System.Security.Cryptography.MD5CryptoServiceProvider
		$utf8 = [System.Text.Encoding]::UTF8
		$str = new-object System.Text.StringBuilder

		$hash = $md5.ComputeHash( $utf8.GetBytes( $_ ) )
		foreach ( $b in $hash ) { [void] $str.Append( $b.ToString( "x2" ) ) }
		$str.ToString()
	}
}
process {
	if( $SnarePassword -is [System.Security.SecureString] ) {
		$SnarePasswordText = [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($SnarePassword))
	} else {
		$SnarePasswordText = $SnarePassword
	}
	
	# Newer versions of Snare uses Digest Auth and here we create
	# the same hashes as in the password form of the web UI.
	# This may need to be changed for future version but works for v4.0.2
	$SnareAccessKeySet = $SnarePasswordText | MD5
	$SnareAccessKeySet1 = "snare:SNARE:$SnarePasswordText" | MD5
	$SnareAccessKeySet2 = "Snare:SNARE:$SnarePasswordText" | MD5
	$SnareAccessKeySet3 = "SNARE:SNARE:$SnarePasswordText" | MD5
	
	$InstallDir = Invoke-Command -Session $Session `
								-ScriptBlock (RemoteInstallScript) `
								-ArgumentList @( $TargetDirectory, $SnareDestination, $SnareAccessKeySet, $SnareAccessKeySet1, $SnareAccessKeySet2, $SnareAccessKeySet3 )

	Write-Host "Copying files..."
	$filesToCopy | %{ 
		sendFile -Source $_ -Destination $( join-path $InstallDir $( $_ | Split-Path -Leaf ) ) -Session $Session
	}

	Write-Host "Starting service..."
	Invoke-Command -Session $Session -ScriptBlock { Start-Service SNARE; Restart-Service Snare }
}
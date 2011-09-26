<#
.SYNOPSIS
	A statsd client in PowerShell which allows sending data to a statsd server over UDP.
.DESCRIPTION
	StatsD by Etsy: https://github.com/etsy/statsd
	
	This is a simple statsd client script written in PowerShell which allows pushing data 
	into Graphite over UDP using a statsd server.
.EXAMPLE
	.\SendTo-Statsd.ps1 -statsDServer statsdserver -target remotex.powershell.statsdclient -Count 322 -SampleRate 0.1
	
	Sends the following data to statsdserver on port 8125:
	remotex.powershell.test:322|c|@0.1

.EXAMPLE
	.\SendTo-Statsd.ps1 -statsDServer 127.0.0.1 -port 1337 -target remotex.powershell.statsdclient -Increment
	
	Sends the following data to 127.0.0.1 on port 1337:
	remotex.powershell.test:1|c

.EXAMPLE
	.\SendTo-Statsd.ps1 -statsDServer statsdserver -target remotex.powershell.statsdclient -Decrement
	
	Sends the following data to statsdserver on port 8125:
	remotex.powershell.test:-1|c

.EXAMPLE
	.\SendTo-Statsd.ps1 -statsDServer statsdserver -target remotex.powershell.statsdclient -Milliseconds 321
	
	Sends the following data to statsdserver on port 8125:
	remotex.powershell.test:321|ms
#>
[CmdletBinding(DefaultParametersetName="Counter")] 
param( 
	[parameter(mandatory=$true)]
	[string] $statsDServer, 
	[int] $port = 8125, 
	[parameter(mandatory=$true)]
	[string[]] $target, 
	[parameter(mandatory=$true, parametersetname="IncrementCounter")]
	[Switch] $Increment,
	[parameter(mandatory=$true, parametersetname="DecrementCounter")]
	[Switch] $Decrement,
	[parameter(mandatory=$true, parametersetname="Counter")]
	[int] $Count,
	[parameter(parametersetname="Counter")]
	[decimal] $SampleRate = 1,
	[parameter(mandatory=$true, parametersetname="Timing")]
	[int] $Milliseconds
)

function CreateSocket( $hostnameOrAddress, $port ) {
	[System.Net.IPAddress]$ip = $null
	if( ![System.Net.IPAddress]::TryParse( $hostnameOrAddress, [ref] $ip ) ) {
		$ip = [System.Net.Dns]::GetHostByName( $hostnameOrAddress ).AddressList | select -First 1
	}
	$socket = New-Object System.Net.Sockets.Socket "InterNetwork", "Dgram", "UDP"
	$socket.Connect( (New-Object System.Net.IPEndPoint $ip, $port) ) 
	$socket
}

function SendAsciiData( $socket ) {
	process {
		$bytes = $socket.Send([System.Text.Encoding]::ASCII.GetBytes($_))
		Write-Verbose "Sent $bytes bytes to socket"
	}
}

filter AsStatsDRecords {
	"{0}:{1}|{2}" -f $_, $Count, $RecordTail
}

$RecordTail = "c"
switch( $PSCmdlet.ParameterSetName ) {
	"IncrementCounter" { $Count = 1 }
	"DecrementCounter" { $Count = -1 }
	"Counter" { 
		if( $SampleRate -ne 1 ) {
			$RecordTail += "|@{0}" -f $SampleRate.ToString( [System.Globalization.CultureInfo]::InvariantCulture )
		}
	}
	"Timing" { $Count = $Milliseconds; $RecordTail = "ms" }
}

$socket = CreateSocket $statsDServer $port
$target | AsStatsDRecords | SendAsciiData $socket

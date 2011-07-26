<#
.SYNOPSIS
	Creates and starts a windows service. 
.DESCRIPTION
	Creates and starts a new windows service with given name and executable. 
#>
[CmdletBinding( SupportsShouldProcess=$true )]
param( 
	[parameter(mandatory=$true, helpmessage="The name of the service")]
	[string] $serviceName,
	[parameter(mandatory=$true, helpmessage="Path to the service executable")]
	[string] $binaryPath,
	[parameter(mandatory=$false, helpmessage="The display name of the service, (if omitted, service name is used)")]
	[string] $displayName,
	[parameter(mandatory=$false, helpmessage="Service description text")]
	[string] $description
	)
if( !$displayName )
{
	$displayName = $serviceName;
}
if( !$description )
{
	$description = $displayName;
}

write-host "Creating service $serviceName"

new-service -Name $serviceName -BinaryPathName $binaryPath -Description $description -DisplayName $displayname

write-host "Starting service $serviceName"

start-service $serviceName
get-service $serviceName

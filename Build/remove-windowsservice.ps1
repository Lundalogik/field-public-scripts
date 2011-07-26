<#
.SYNOPSIS
	Delete a windows service. 
.DESCRIPTION
	Deletes an already existing windows service. Must be run as administrator
#>
[CmdletBinding( SupportsShouldProcess=$true )]
param( 
	[parameter(mandatory=$true, helpmessage="The name of the service to delete")]
	[string] $serviceName
	)

write-host "Looking for service $serviceName"
$service = Get-WmiObject -class Win32_Service | ?{$_.Name -eq $serviceName }
if (!$service)
{
	throw "Service $serviceName not found"
}

write-host "Service state is $($service.State)"

if( $service.State -ne "Stopped" )
{
	write-host "Stopping service";
	$res = $service.StopService();
	if( $res.ReturnValue -ne 0 )
	{
		throw "Couldn't stop service $serviceName. $res"
	}
}

write-host "Deleting service"
$res = $service.Delete();
if( $res.ReturnValue -eq 0 )
{
	write-host "Service $serviceName was deleted"
}
else
{
	throw "Couldn't delete service $serviceName. $res"
}

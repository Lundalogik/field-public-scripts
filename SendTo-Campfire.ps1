<#
Usage:

$Env:CAMPFIRE_DEFAULT_ROOMNUMBER="123456"
$Env:CAMPFIRE_TOKEN="abcdef1234567890...."
$Env:CAMPFIRE_SUBDOMAIN="yoursubdomain"

"rimshot" | SendTo-Campfire.ps1 -PlaySound
SendTo-Campfire.ps1 "trombone" -PlaySound
SendTo-Campfire.ps1 "say hello"
#>
param (
	[parameter(mandatory=$true,valuefrompipeline=$true)]
	[string]$Body,
	[switch]$PlaySound,
	[string]$RoomNumber = $Env:CAMPFIRE_DEFAULT_ROOMNUMBER,
	[string]$AuthToken = $Env:CAMPFIRE_TOKEN,
	[string]$SubDomain = $Env:CAMPFIRE_SUBDOMAIN
)

if( !$AuthToken ) {
	throw "Auth token is missing. Set parameter explicitly or give `$Env:CAMPFIRE_TOKEN a value"
}

if( !$SubDomain ) {
	throw "Sub domain is missing. Set parameter explicitly or give `$Env:CAMPFIRE_SUBDOMAIN a value"
}

if( !$RoomNumber ) {
	throw "Room number is missing. Set parameter explicitly or give `$Env:CAMPFIRE_DEFAULT_ROOMNUMBER a value"
}

$postUrl = "https://{0}.campfirenow.com/room/{1}/speak.json" -f $SubDomain, $RoomNumber
$msg = New-Object psobject -Property @{ body = $Body }
if( $PlaySound ) {
	$msg | Add-Member -MemberType NoteProperty -Name "type" -Value "SoundMessage"
}
$payload = New-Object psobject -Property @{ message = $msg }
$result = $payload | convertto-json -compress | curl -i -u "${AuthToken}:X" -H 'Content-Type: application/json' -d `@- $postUrl 2>&1
if ( !($result | ?{ $_ -match "Created$" }) ) {
	Write-Host "Error posting message to Campfire" -foregroundcolor red
}
elseif( $PlaySound ) {
	Write-Host "Played sound '$Body' in room $RoomNumber on Campfire" -foregroundcolor green
} else {
	Write-Host "Posted message '$Body' to room $RoomNumber on Campfire" -foregroundcolor green
}
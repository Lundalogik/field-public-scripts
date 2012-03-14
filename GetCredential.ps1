<#
# Alternative to Get-Credential which allows one to supply credentials to 
# Invoke-Command and such without the UI dialog. This can be useful for 
# unattended scripts where a UI cant be used.
#
# Example:
# Invoke-Command -ComputerName srv01 `
#                -Authentication Basic `
#                -Credential (GetCredential.ps1 -username foo -password bar) `
#                -ScriptBlock { pwd }
#
# A prompt will appear username and/or password arguments are omitted.
#>
param(
	[parameter( mandatory = $false )]
	[string] $Username,
	[parameter( mandatory = $false )]
	$Password,
	[Switch] $AsNetworkCredential
)

while( [String]::IsNullOrEmpty( $Username ) )
{
	$Username = Read-Host -Prompt "Username"
}

$Credential = $null
if( $Password -is [String] -and ![String]::IsNullOrEmpty( $Password ) )
{
	$Credential = new-object System.Management.Automation.PSCredential( $Username, (ConvertTo-SecureString -AsPlainText -Force -String $Password) )
}
if( $Password -is [System.Security.SecureString] )
{
	$Credential = new-object System.Management.Automation.PSCredential( $Username, $Password )
}

while( $Credential -eq $null )
{
	$SecurePassword = Read-Host -AsSecureString -Prompt "Password"
	$Credential = new-object System.Management.Automation.PSCredential( $Username, $SecurePassword )
}

if( $AsNetworkCredential )
{
	$Credential.GetNetworkCredential()
}
else
{
	$Credential
}


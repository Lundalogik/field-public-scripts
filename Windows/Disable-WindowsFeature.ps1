param(
	[parameter(mandatory=$true)]
	[String[]] $features
)

$availableFeatures = @{}
dism /online /get-features /format:table | %{
	if( $_ -imatch "^([^\|]+).+(Enabled|Disabled)" ) {
		$availableFeatures.Add( $matches[1].Trim(), $matches[2].Trim() )
	}				
}
if( $LASTEXITCODE -ne 0 ) {
	throw "DISM returned error $LASTEXITCODE - Are you running in non-elevated mode?"
}

$toUninstall = @()
$features | %{
	if( $availableFeatures.ContainsKey( $_ ) ) {
		if( $availableFeatures[$_] -eq "Disabled" ) {
			Write-Host "$_ is already disabled"
		} else {
			$toUninstall += $_
		}
	} else {
		Write-Host "Error: Feature $_ does not exist on this machine"
	}
}
if( !$toUninstall ) {
	Write-Host "All features are already installed"
} else {
	Write-Host "Disabling $(($toUninstall | measure).Count) features: $toUninstall"
	Invoke-Expression "dism /norestart /online /disable-feature /featurename:$([string]::join(' /featurename:', $toUninstall))"
}
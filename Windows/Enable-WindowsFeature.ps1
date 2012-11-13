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

$toInstall = @()
$features | %{
	if( $availableFeatures.ContainsKey( $_ ) ) {
		if( $availableFeatures[$_] -eq "Enabled" ) {
			Write-Host "$_ is already enabled"
		} else {
			$toInstall += $_
		}
	} else {
		Write-Host "Error: Feature $_ does not exist on this machine"
	}
}
if( !$toInstall ) {
	Write-Host "All features are already installed"
} else {
	Write-Host "Enabling $(($toInstall | measure).Count) features: $toInstall"
	Invoke-Expression "dism /norestart /online /enable-feature /featurename:$([string]::join(' /featurename:', $toInstall))"
}
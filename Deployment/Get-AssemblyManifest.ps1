<#
.SYNOPSIS
	Takes an URL or path to an application manifest file and summarizes its contents.
	Useful for verifying the contents of an application deployed using ClickOnce or an VSTO plugin.
#>
param( [string] $manifestPathOrUrl )

Set-Alias curl 'curl.exe'

$manifestXml = ""
if( $manifestPathOrUrl -imatch "^https?:" ) {
	$manifestXml = [xml](curl -sk $manifestPathOrUrl)
} else {
	$manifestXml = [xml](gc $manifestPathOrUrl)
}

function Get-SizeFormatted ($bytes,$precision='0') {
	foreach( $metric in "Bytes","KB","MB","GB","TB" ) { 
		if ( $bytes -lt 1000 -or $metric -eq "TB" ){ 
			return "{0:F0$precision} {1}" -f $bytes, $metric
		} else {
			$bytes /= 1KB
		} 
	} 
}

$dependentAssemblies = $manifestXml.SelectNodes("//*[local-name()='dependentAssembly' and @dependencyType!='preRequisite']") | select @{Expression={$_.codebase}; Label="name"}, size
$files = $manifestXml.SelectNodes("//*[local-name()='file']") | select name, size
$all = $dependentAssemblies + $files
$all | sort @{Expression={[long]$_.size}} -Descending | ft -AutoSize name, @{Expression={Get-SizeFormatted $_.size}; Label="Size"}

"Files and assemblies: {0}`r`nTotal size: {1}" -f ($all | measure).Count, (Get-SizeFormatted ($all | measure -Sum Size).Sum)

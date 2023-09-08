<#
.SYNOPSIS
	Reads the AssemblyVersion attribute from a .CS file and returns an object representation of the version
.DESCRIPTION
	Specify the path to the .CS file and returned is an object with the properties Version (complete version number in a dotted format), Major, Minor, Build and Revision numbers.
#>
param(
	[parameter(mandatory=$true)]
	[string] $assemblyInfoFile 
)

$version = "" | select Major, Minor, Build, Revision | Add-Member -PassThru -Name Version -MemberType ScriptProperty -Value { "$($this.Major).$($this.Minor).$($this.Build).$($this.Revision)" }

Get-Content $assemblyInfoFile | %{ 
	if( $_ -match "AssemblyVersion(Attribute)?\s*\(\s*`"(\d+)\.(\d+)\.(\d+)\.(\d+)`"\s*\)" ) {
		$version.Major = [int]$matches[2]
		$version.Minor = [int]$matches[3]
		$version.Build = [int]$matches[4]
		$version.Revision = [int]$matches[5]
	}
}

$version
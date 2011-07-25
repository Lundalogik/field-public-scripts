<#
.SYNOPSIS
	Writes the AssemblyVersion attribute version to a specified .CS file path
.DESCRIPTION
	Given an existing .CS file containing an AssemblyVersion attribute, this script will update its version number according to the parameters specified.
#>
param(
	[parameter(position=0, mandatory=$true)]
	[string] $assemblyInfoFile,
	[parameter(mandatory=$true, parametersetname="GivenNumber", helpmessage="The major part of the version")]
	[int] $major,
	[parameter(mandatory=$true, parametersetname="GivenNumber", helpmessage="The minor part of the version")]
	[int] $minor,
	[parameter(mandatory=$true, parametersetname="GivenNumber", helpmessage="The build part of the version")]
	[int] $build,
	[parameter(mandatory=$true, parametersetname="GivenNumber", helpmessage="The revision part of the version")]
	[int] $revision,
	[parameter(mandatory=$true, valuefrompipeline=$true, parametersetname="GivenVersionObject", helpmessage="A object with Major, Minor, Build and Revision properties")]
	$InputObject
)

if( $InputObject -ne $null ) {
	$major = $InputObject.Major
	$minor = $InputObject.Minor
	$build = $InputObject.Build
	$revision = $InputObject.Revision
}

Write-Host "Updating version to $major.$minor.$build.$revision"

$lines = (gc $assemblyInfoFile) -replace "(?<=Assembly(File)?Version(Attribute)?\s*\(\s*`")(\d+\.\d+\.\d+\.\d+)(?=`"\s*\))", "$major.$minor.$build.$revision"
$lines | sc $assemblyInfoFile
$newVersion = iex "$($MyInvocation.MyCommand.Path | Split-Path)\get-assemblyversion.ps1 -assemblyInfoFile $assemblyInfoFile"

if( $newVersion.Major -ne $major -or $newVersion.Minor -ne $minor -or $newVersion.Build -ne $build -or $newVersion.Revision -ne $revision ) {
	throw "Error setting AssemblyVersion. Expected version $major.$minor.$build.$revision but $($newVersion.Major).$($newVersion.Minor).$($newVersion.Build).$($newVersion.Revision) was saved to the file $assemblyInfoFile"
}
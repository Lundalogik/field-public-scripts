<#
.SYNOPSIS
	Expands the a zip file to a target directory
.DESCRIPTION
	All items in the zip file will be extracted to the directory
	given by the -target argument. The given target directory will
	be created if it does not exist.

	The file will expand into the current directory if -target is
	omitted.

	  PS> .\Expand-ZipFile.ps1 file.zip 
	  PS> .\Expand-ZipFile.ps1 file.zip c:\temp\createme

	Credit to the author of and inspiration from the original item: 
	http://poshcode.org/4198
#>
param(
	[parameter(mandatory=$true)]
	$path,
	$target = $pwd
)
Add-type -AssemblyName "System.IO.Compression.FileSystem"
$path = Resolve-Path $path | % Path

if( !(Test-Path $target)) {
	mkdir $target
}

$zip = [System.IO.Compression.ZipFile]::Open( $path, "Read" )
try {
	$zip.Entries | % {
		$entryPath = join-path $target $_.FullName
		if( $_.Name -eq '' ) {
			mkdir $entryPath -force
		} else {
			[System.IO.Compression.ZipFileExtensions]::ExtractToFile( $_, $entryPath, $true )
		}
	}
} finally {
	if( $zip -ne $null ) {
		$zip.Dispose()
	}
}
<#
.SYNOPSIS
	Creates a zip archive out of the given input files
.DESCRIPTION
	Either specify the contents of the archive using the pipeline:

	  PS> gi .\dir1, .\dir2 | .\New-ZipFile.ps1 dirs.zip

	(the zip will have dir1 and dir2 in its root)

	...or given by argument:

	  PS> .\New-ZipFile.ps1 dir.zip .\dir1

	Credit to the author of and inspiration from the original item: 
	http://poshcode.org/4198
#>
param(
	[parameter(mandatory=$true)]
	$target,
	[parameter(mandatory=$true, ValueFromPipelineByPropertyName=$true)]
	[alias("FullName")]
	[string[]]$files
	)
begin {
	Add-type -AssemblyName "System.IO.Compression.FileSystem"
	if(Test-Path $target) { Remove-Item $target -force }
	$zip = [System.IO.Compression.ZipFile]::Open( $target, "Create" )
}
process {
	$files | Resolve-Path | ls -recurse -force -file | % FullName | % {
		$relativePath = Resolve-Path $_ -Relative
		[void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_, $relativePath.TrimStart(".\"), [System.IO.Compression.CompressionLevel]::Optimal)
	}
}
end {
	$zip.Dispose()
	Get-Item $target
}
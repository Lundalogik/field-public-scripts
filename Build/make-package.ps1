<#
.SYNOPSIS
	make-package.ps1 is a tool which reads packaging instructions from files named "package.spec" and executes them. 
.DESCRIPTION
	The result is a package directory with only those files that were specified by the instructions.
	The package.spec file can contain series of the following commands:
	
	from      - a source directory relative to the package.spec file location
	to        - a target directory relative to the root of the package directory
	norecurse - turns off recursive traversal of the source directory
	include   - a comma-separated list of file patterns to include when copying files
	exclude   - a comma-separated list of file patterns to exclude when copying files
	
	Both include and exclude must be either relative to the source directory or contain
	a file name pattern without a relative directory.
	
	Commands can be split up over several lines if they are indented.
	OK:
	include *.xml,
			*.xaml
	
	NOT OK:
	include *.xml,
	*.xaml
	
	All lines that begins with a '#' character are treated as comments.
	
.EXAMPLE
	Directory WebApp has the following structure:
	Resources/logo.png
	Web/bin/Web.dll
	Web/bin/Web.pdb
	Web/bin/Web.xml
	Web/Web.config
	Web/index.html
	Production/Web.config
	package.spec
	WebApp.sln
	
	package.spec:
	from Web
	to \
	include *.*
	exclude Web.config
	
	from Production
	to \
	include *.*
	
	from Web\bin
	to bin
	include *.*
	exclude *.xml,
			*.pdb
	
	from Resources
	to Images
	include *.png
	
	The following commands are issued to create the package, assuming the sources are in a folder called "src",
	and finally list the result:
	
	mkdir WebApp-1-0-0 | cd
	make-package -specRootDirectory ..\src
	ls -Recurse | select FullName
	
	FullName
	--------
	\WebApp-1-0-0\bin
	\WebApp-1-0-0\Images
	\WebApp-1-0-0\index.html
	\WebApp-1-0-0\web.config
	\WebApp-1-0-0\bin\Web.dll
	\WebApp-1-0-0\Images\logo.png

.EXAMPLE 
	make-package.ps1 -specRootDirectory ..\src -whatif

	Cmdlet switch -WhatIf is supported by this script and will let you see the script would do if you ommited the switch:
	
	Looking for package files in ..\src ...
	Processing \src\package.spec
	What if: Performing operation "Copy File" on Target "Item: \src\Web\index.html Destination: \WebApp-1-0-0\index.html".
	What if: Performing operation "Copy File" on Target "Item: \src\Production\web.config Destination: \WebApp-1-0-0\web.config".
	What if: Performing operation "Create directory" on Target "\WebApp-1-0-0\bin".
	What if: Performing operation "Copy File" on Target "Item: \src\Web\bin\Web.dll Destination: \WebApp-1-0-0\bin".
	What if: Performing operation "Create directory" on Target "\WebApp-1-0-0\Images".
	What if: Performing operation "Copy File" on Target "Item: \src\Resources\logo.png Destination: \WebApp-1-0-0\Images".

.EXAMPLE
	make-package.ps1 -specRootDirectory ..\src -Verbose
	
	Cmdlet switch -Verbose is supported by this script and can be useful to debug your package.spec files.
	It will not only tell you what files that are included, but also files which were excluded and by which exclusion pattern:

	Looking for package files in ..\src ...
	Processing \src\package.spec
	VERBOSE: === \src\package.spec:1 ===
	VERBOSE: basedirectory: \src
	VERBOSE: exclude: Web.config
	VERBOSE: from: Web
	VERBOSE: include: *.*
	VERBOSE: to: \
	VERBOSE: Processing \src\Web\*.*
	VERBOSE: Performing operation "Copy File" on Target "Item: \src\Web\index.html Destination: \WebApp-1-0-0\index.html".
	VERBOSE: Skipping Web.config (Web.config)
	VERBOSE: === \src\package.spec:6 ===
	VERBOSE: basedirectory: \src
	VERBOSE: from: Production
	VERBOSE: include: *.*
	VERBOSE: to: \
	VERBOSE: Processing \src\Production\*.*
	VERBOSE: Performing operation "Copy File" on Target "Item: \src\Production\web.config Destination: \WebApp-1-0-0\web.config".
	VERBOSE: === \src\package.spec:10 ===
	VERBOSE: basedirectory: \src
	VERBOSE: exclude: *.xml *.pdb
	VERBOSE: from: Web\bin
	VERBOSE: include: *.*
	VERBOSE: to: bin
	VERBOSE: Performing operation "Create directory" on Target "\WebApp-1-0-0\bin".
	VERBOSE: Processing \src\Web\bin\*.*
	VERBOSE: Performing operation "Copy File" on Target "Item: \src\Web\bin\Web.dll Destination: \WebApp-1-0-0\bin\Web.dll".
	VERBOSE: Skipping Web.pdb (*.pdb)
	VERBOSE: Skipping Web.xml (*.xml)
	VERBOSE: === \src\package.spec:16 ===
	VERBOSE: basedirectory: \src
	VERBOSE: from: Resources
	VERBOSE: include: *.png
	VERBOSE: to: Images
	VERBOSE: Performing operation "Create directory" on Target "\WebApp-1-0-0\Images".
	VERBOSE: Processing \src\Resources\*.png
	VERBOSE: Performing operation "Copy File" on Target "Item: \src\Resources\logo.png Destination: \WebApp-1-0-0\Images\logo.png".
#>
[CmdletBinding( SupportsShouldProcess=$true )]
param( 
	[parameter(mandatory=$true, parametersetname="FindSpecFiles", helpmessage="Specifies the root directory to look in for package.spec files")]
	[string] $specRootDirectory,
	[parameter(mandatory=$true, parametersetname="GivenSpecFiles", helpmessage="Specifies a list of paths to spec files to process")]
	[String[]] $specFiles
)

$packageDir = Resolve-Path .

function HashToSpecObject( $hash ) {
	# Make arrays of include and exclude
	"include","exclude" | %{
		if( $hash[$_] -ne $null ) {
			$hash[$_] = $hash[$_].Split(",")
		}
	}
	new-object PSObject -Property $hash
}

function HashSpec( $specFile, $lineNumber = 1 ) {
	@{ "basedirectory" = $specFile.Directory; "specfile" = $specFile.FullName; "linenumber" = $lineNumber }
}

function IsValidSpecHash( $spec ) {
	$spec["from"] -ne $null -and $spec["to"] -ne $null
}

filter AsPackageSpec {
	$specFile = $_
	Write-Host "Processing $($specFile.FullName)"
	$spec = HashSpec $specFile
	$lastKey = ""
	$lineNumber = 0
	gc $specFile.FullName | %{
		$lineNumber++
		if( $_ -match "^([^\s#]+)(\s+(.+))?$" ) {
			if( $matches[1] -eq "from" -and (IsValidSpecHash $spec ) ) {
				# yield spec, jump on to the next
				HashToSpecObject $spec
				$spec = HashSpec $specFile $lineNumber
			}
			if( $matches[3] -eq $null ) {
				$val = $true
			} else {
				$val = $matches[3]
			}
			$spec[$matches[1]] = $val
			$lastKey = $matches[1]
		}
		if( $_ -match "^\s+([^#].*)$" ) {
			$spec[$lastKey] += $matches[1]
		}
	}
	if( IsValidSpecHash $spec ) {
		HashToSpecObject $spec
	} elseif( $spec['from'] -eq $null ) {
		throw "Spec file is invalid: $specfile Missing 'from' directive"
	} elseif( $spec['to'] -eq $null ) {
		throw "Spec file is invalid: $specfile Missing 'to' directive"
	}
}

function CreateDirectoryIfNotExists( $directory ) {
	if( !(Test-Path -PathType Container $directory) ) {
		if( $pscmdlet.ShouldProcess( $directory, "Create directory" ) ) {
			mkdir $directory | Out-Null
		}
	}
}

function CopyToPackage() {
	process {
		$spec = $_
		Write-Verbose "=== $($spec.specfile):$($spec.linenumber) ==="
		$spec | gm -MemberType NoteProperty | ?{ $_.Name -ne "specfile" -and $_.Name -ne "linenumber" } | %{
			Write-Verbose "$($_.Name): $(iex '$spec.$($_.Name)')"
		}
		$targetDir = join-path $packageDir $spec.to
		CreateDirectoryIfNotExists $targetDir
		$sourceDir = Join-Path -Resolve $spec.basedirectory $spec.from
		$recursive = $spec.norecurse -ne $true
		$spec.include | %{ 
			Write-Verbose "Processing $sourceDir\$_"
			$specErrors = @()
			$items = @()
			if( $recursive ) {
				$items = dir -ErrorAction SilentlyContinue -ErrorVariable +specErrors $sourceDir -include $_ -recurse
			} else {
				$items = dir -ErrorAction SilentlyContinue -ErrorVariable +specErrors $sourceDir\$_
			}
			if( $items -ne $null ) {
				$items | ?{ 
					$source = $_.FullName
					$relativePath = $source.Substring( $sourceDir.Length ).Trim( '\' )
					$exclusions = $spec.exclude | ?{ 
						#Write-Verbose "$relativePath -like $_ = $($relativePath -like $_)"; 
						$relativePath -like $_ 
					}

					if( ($exclusions | measure).Count -ne 0 ) {
						Write-Verbose "Skipping $relativePath ($exclusions)"
					} else { 
						$destination = [System.IO.Path]::Combine( $targetDir, [System.IO.Path]::GetDirectoryName( $relativePath ))
						try {
							CreateDirectoryIfNotExists $destination
							copy -ErrorAction SilentlyContinue -ErrorVariable +specErrors -Recurse -Force -Path $source -Destination $destination -WhatIf:$WhatIfPreference -Verbose:$($VerbosePreference -eq "Continue")
						} catch {
							Write-Error "Error processing spec: `r`n$($spec | fl)"
							throw $_
						}
					}
				}
			}
			
			if( $specErrors.Count -gt 0 ) {
				Write-Warning "Errors at $($spec.specfile):$($spec.linenumber): `r`n$specErrors"
			}
		}
	}
}

function CallPackageScripts() {
	process {
		$spec = $_
		$packageScript = $spec.specfile -replace "\.spec$",".ps1"
		if( Test-Path $packageScript ) {
			$supportsWhatIf = $WhatIfPreference -and (Get-Command $packageScript | select -ExpandProperty ParameterSets | select -ExpandProperty Parameters | ?{ $_.Name -eq "WhatIf" } | measure | select -ExpandProperty Count) -gt 0
			Write-Verbose "=== Calling package script $packageScript ==="
			$packageScript | Split-Path | pushd
			try {
				if( $supportsWhatIf ) {
					& $packageScript -WhatIf
				} elseif( !$WhatIfPreference ) {
					& $packageScript | %{ Write-Verbose "> $_" }
				}
			} finally {
				popd
			}
			Write-Verbose "=== Done: $packageScript ==="
		}
	}
}

if( $specFiles -eq $null ) {
	Write-Host "Looking for package files in $specRootDirectory ..."
	$fileInfos = dir -Recurse $specRootDirectory -Include package.spec
} else {
	$fileInfos = $specFiles | %{ gi $_ }
}

$specs = $fileInfos | AsPackageSpec
$specs | CallPackageScripts
$specs | CopyToPackage

<#
.SYNOPSIS
	Installs Ruby on Windows in a configure && make && make install fashion
.DESCRIPTION
	Uses either the latest version published at RubyInstaller.org or a source directory in which the
	ruby*mingw.7z and DevKit*sfx.exe files already are present.
	
	Installation will setup the DevKit and try to verify the installation by installing the RDiscount
	gem as described here: https://github.com/oneclick/rubyinstaller/wiki/Development-Kit
	
	The DevKit will be installed beneath the destination directory. I.e.:
	c:\ruby
	c:\ruby\devkit
	
	The script needs both curl and 7Zip and will fail if curl.exe/7za.exe is not available.

.PARAMETER destination
	The destination directory. C:\ruby will put C:\ruby\bin in the path and the devkit in C:\ruby\devkit.
.PARAMETER addToPath
	Default. Will add the necessary directories for ruby/the devkit to the path
.PARAMETER environmentTarget
	Default is User. Run with elevated privileges and use Machine if you need ruby in the SYSTEM path
.PARAMETER packagesSourceDir
	Will skip fetching packages from RubyInstaller.org and use the directory you specify.
	Using this option eliminates the requirement of having curl.exe in the path. However you still need 7za.exe.
#>
param( 
	[parameter(mandatory=$true)]
	$destination,
	[switch] $addToPath = [switch]::Present,
	[System.EnvironmentVariableTarget] $environmentTarget = [System.EnvironmentVariableTarget]::User,
	$packagesSourceDir = ""
)
if( !(Get-Command 7za.exe) ) {
	throw "Missing 7za.exe"
}
if( !$packagesSourceDir -and !(Get-Command curl.exe) ) {
	throw "Missing curl.exe"
}

Set-Alias sevenza 7za.exe

$tempDir = Join-Path $env:TEMP "rubyinstall"
if( test-path $tempDir ) { rm -force -recurse $tempDir }
mkdir $tempDir | Push-Location 

if( $packagesSourceDir ) {
	Write-Host "Browsing package source dir $packagesSourceDir ..."
	$rubySource = ls $packagesSourceDir -Filter "ruby*mingw32.7z" | select -First 1 -ExpandProperty FullName
	$devKitSource = ls $packagesSourceDir -Filter "DevKit*sfx.exe" | select -First 1 -ExpandProperty FullName
	Write-Host "Found release $rubySource"
	Write-Host "Found devkit $devKitSource"
	cp $rubySource ruby.7z
	cp $devKitSource devkit.7z
} else {
	Write-Host "Browsing archive at rubyinstaller.org ..."
	$archive = curl -s http://rubyinstaller.org/downloads/archives
	$rubyInstallerUrl = $archive | select-string "http://[^""]+mingw32\.7z" | select -First 1 -ExpandProperty Matches | select -ExpandProperty Value
	$rubyDevKitUrl = $archive | select-string "http://[^""]+-sfx\.exe" | select -First 1 -ExpandProperty Matches | select -ExpandProperty Value
	Write-Host "Found release $rubyInstallerUrl"
	Write-Host "Found devkit $rubyDevKitUrl"
	curl -L -o ruby.7z $rubyInstallerUrl 
	curl -L -o devkit.7z $rubyDevKitUrl
}
sevenza x ruby.7z
$rubyDirTemp = gi ruby-*-mingw32 
cd $rubyDirTemp
mkdir devkit | cd
sevenza x ..\..\devkit.7z
Write-Host "Installing at $destination and $destination\devkit"
if( test-path $destination ) { rm -force -recurse $destination }
mv $rubyDirTemp $destination
Pop-Location

if( $addToPath ) {
	$path = [Environment]::GetEnvironmentVariable( "Path", $environmentTarget )
	$rubyBin = Join-Path -Resolve $destination "bin"
	$rubyDevKitBin = Join-Path -Resolve $destination "devkit\bin"
	$rubyDevKitMingwBin = Join-Path -Resolve $destination "devkit\mingw\bin"
	$rubyPathRx = "^(\w:|%[^%]+%)\\ruby.*\\bin$"
	$newPath = [String]::Join( ";", ( $path.Split( ";" ) | ?{ $_ -notmatch $rubyPathRx } ) + $rubyBin + $rubyDevKitBin + $rubyDevKitMingwBin )
	# make it available in the current shell
	$env:Path = [String]::Join( ";", ( ${env:Path}.Split( ";" ) | ?{ $_ -notmatch $rubyPathRx } ) + $rubyBin + $rubyDevKitBin + $rubyDevKitMingwBin  )
	Write-Host "New path set to $newPath"
	try {
		[Environment]::SetEnvironmentVariable( "Path", $newPath, $environmentTarget )
	} catch {
		Write-Error "Failed to set PATH - perhaps you are not running in elevated mode?"
	}
}

$rubyExe = Join-Path $destination "\bin\ruby.exe"
$gemBat = Join-Path $destination "\bin\gem.bat"
Set-Alias ruby $rubyExe
Set-Alias gem $gemBat

Push-Location $destination\devkit
ruby dk.rb init
" - $($destination.Replace('\','/'))" | Out-File -Append -FilePath config.yml -Encoding ASCII
ruby dk.rb install
Pop-Location
gem install rdiscount --platform=ruby
$test = cmd.exe /c $rubyExe -rubygems -e "require 'rdiscount'; puts RDiscount.new('**Hello RubyInstaller**').to_html"
if( $test -like "*<strong>Hello RubyInstaller</strong>*" ) {
	Write-Host "Installation of devkit and building of gem rdiscount verified successfully!"
} else {
	Write-Host "Oh my! Failed to verify devkit ability to build gem rdiscount.: $test"
}
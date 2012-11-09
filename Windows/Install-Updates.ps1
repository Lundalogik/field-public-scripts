<#
.SYNOPSIS
	Installs Windows Updates
.DESCRIPTION
	Installs the updates currently available for install.
	Will install updates according to the options chosen, except for updates which requires user interaction.
	To accept any EULAs during the installation process - use the -Force.
.PARAMETER SoftwareOnly
	Default. Will add the criteria Type='Software' when looking for updates
.PARAMETER AutomaticUpdatesOnly
	Default. Will add the criteria IsAssigned=1 when looking for updates
.PARAMETER AllowReboot
	Default. Will reboot the system after installation if any installed update may require this.
.PARAMETER WhatIf
	The script will only tell what updates it would install without the switch 
.PARAMETER Force
	If used, any EULA that is not accepted will be accepted

#>
[cmdletbinding()]
param(
	[Switch] $SoftwareOnly = [Switch]::Present,
	[Switch] $AutomaticUpdatesOnly = [Switch]::Present,
	[Switch] $AllowReboot = [Switch]::Present,
	[Switch] $WhatIf,
	[Switch] $Force
)
filter Tell {
	$action = @()
	if( !$_.IsDownloaded ) {
		$action += "Download"
	}
	if( !$_.IsInstalled ) {
		$action += "Install"
	}
	
	New-Object psobject -Property @{ "Title" = $_.Title; "Action" = $action; "RequiresReboot" = $_.InstallationBehavior.RebootBehavior -le 0 }
}
filter AcceptedUpdates {
	if( !$_.EulaAccepted -and $Force ) {
		$_.AcceptEula()
	}
	if( $_.EulaAccepted ) {
		$_
	}
}
filter ResultToString {
	switch( $_ ) {
		0 { "NotStarted" }
		1 { "InProgress" }
		2 { "Successful" }
		3 { "SucceededWithErrors" }
		4 { "Failed" }
		5 { "Aborted" }
	}
}

$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$searcher = $UpdateSession.CreateUpdateSearcher()
$criteria = "IsHidden=0 and IsInstalled=0"
if( $AutomaticUpdatesOnly ) {
	$criteria += " and IsAssigned=1"
}
if( $SoftwareOnly ) {
	$criteria += " and Type='Software'"
}

function GetUpdates( $criteria ) {
	$searcher.Search( $criteria ) `
		| select -ExpandProperty Updates `
		| ?{ !$_.InstallationBehavior.CanRequestUserInput }
}

function DownloadUpdates( $updates ) {
	$forDownload = $updates | ?{ !$_.IsDownloaded }
	$count = ($forDownload | measure).Count
	
	if( $count -eq 0 ) {
		return
	}
	
	Write-Host ("Trying to download {0} updates" -f $count)
	$downloader = $UpdateSession.CreateUpdateDownloader()
	$dlCollection = new-object -comobject Microsoft.Update.UpdateColl
	$forDownload | %{ $dlCollection.Add( $_ ) | Out-Null }
	$downloader.Updates = $dlCollection
	try {
		$downloader.Download() | Out-Null
	} catch {
		if( $_.Exception.Message -like "*Exception from HRESULT: 0x80240044*" ) {
			throw "This command must be run with elevated privileges"
		} else {
			throw $_
		}
	}
}

function InstallUpdates( $updates ) {
	$forInstall = $updates | ?{ !$_.IsInstalled }
	$count = ($forInstall | measure).Count
	
	if( $count -eq 0 ) {
		return
	}
	Write-Host ("Found {0} updates to install" -f $count)
	$installer = $UpdateSession.CreateUpdateInstaller()
	$installCollection = new-object -comobject Microsoft.Update.UpdateColl
	$updatesForInstall | %{ $installCollection.Add( $_ ) | out-null }
	$installer.Updates = $installCollection
	try {
		new-object psobject -Property @{ "Result" = $installer.Install(); "Updates" = $installCollection }
	} catch {
		if( $_.Exception.Message -like "*Exception from HRESULT: 0x80240044*" ) {
			throw "This command must be run with elevated privileges"
		} else {
			throw $_
		}
	}
}

$updates = GetUpdates $criteria
Write-Host ("Found {0} updates" -f $updates.Count)
if( $updates.Count -eq 0) {
	return
}

if( $WhatIf ) {
	$updates | Tell | ft -AutoSize
} else {
	$acceptedUpdates = $updates | AcceptedUpdates
	DownloadUpdates $acceptedUpdates
	
	$updatesForInstall = GetUpdates $criteria | ?{ $AllowReboot -or $_.InstallationBehavior.RebootBehavior -le 0 }
	$installResult = InstallUpdates $updatesForInstall
	
	$installCollection = $installResult.Updates
	if( $installCollection.Count -le 0 ) {
		Write-Host "Already up to date."
		return
	}
	Write-Host "Installation result:"
	$updatesInstalled = @()
	for( $i = 0; $i -lt $installCollection.Count; $i++ ) {
		$updatesInstalled += new-object psobject -Property @{ "Title" = $installCollection.item($i).Title; "Result" = $installResult.Result.GetUpdateResult($i).ResultCode | ResultToString }
	}
	$updatesInstalled | ft -AutoSize | Out-Host

	if( $installResult.Result -ne $null -and $installResult.Result.ResultCode -ne 2 ) {
		throw "Installation failed. Result: $($installResult.Result.ResultCode)"
	}
	
	if( $installResult.Result.RebootRequired -and $AllowReboot ) {
		Write-Host "Rebooting system..."
		Restart-Computer -Force
	}
}
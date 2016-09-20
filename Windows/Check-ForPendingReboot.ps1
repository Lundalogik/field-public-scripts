$requiresRebootKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
$needsReboot = Test-Path $requiresRebootKey
if( $needsReboot ) {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $searcher = $UpdateSession.CreateUpdateSearcher()
    $updateIds = Get-Item $requiresRebootKey | select -ExpandProperty Property | ?{ $_.Contains("-") }
    Write-Host ("There are {0} pending updates which requires a reboot" -f ($updateIds | measure).Count)
}
$needsReboot

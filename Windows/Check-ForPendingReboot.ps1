$requiresRebootKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
$needsReboot = Test-Path $requiresRebootKey
if( $needsReboot ) {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $searcher = $UpdateSession.CreateUpdateSearcher()
    $updateIds = Get-Item $requiresRebootKey | select -ExpandProperty Property
    Write-Host ("There are {0} pending updates which requires a reboot" -f ($updateIds | measure).Count)
    if( $updateIds ) {
        $criteria = [String]::Join( " OR ", ( $updateIds | %{ "UpdateId='$_'" } ) )
        $result = $searcher.Search( $criteria ).Updates
		Write-Host "Updates found (all may not be listed):"
        for( $i = 0; $i -lt $result.Count; $i++) {
            $update = $result.Item($i)
            Write-Host $update.Title
        }
    }
}
$needsReboot
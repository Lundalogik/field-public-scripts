# Turns on automatic updates
Write-Host "Turning on automatic update setting in registry"
New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -name 'AUOptions' -value '4' -propertyType "DWord" -force | Out-Null
Write-Host -NoNewline "Enabling service.."
$AU = New-Object -com "Microsoft.Update.AutoUpdate"
$AU.EnableService()
Set-Service wuauserv -StartupType Automatic
Start-Service wuauserv
Write-Host "Done"
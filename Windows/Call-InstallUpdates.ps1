param(
  [switch] $OptionalUpdates,
  [switch] $RebootIfNeeded )

Set-Alias registerTask ( join-path -resolve $PSScriptRoot "Register-TaskForWindowsUpdate.ps1" )
Set-Alias getTask ( join-path -resolve $PSScriptRoot "Get-Task.ps1" )
Set-Alias checkForPendingReboot ( join-path -resolve $PSScriptRoot "Check-ForPendingReboot.ps1" )
$task = registerTask -OptionalUpdates:$OptionalUpdates
$task.Run()
do {
	sleep -Seconds 10
	$task = getTask $task.TaskName
	Write-Host ("Windows Update task is {0}" -f $task.Status)
} while( $task.Status -eq "Running" )
$needsReboot = checkForPendingReboot

Write-Host "Reboot needed: $needsReboot"

if( $needsReboot ) {
  if( $RebootIfNeeded ) {
    Write-Host "A reboot is needed and option to automatically reboot is enabled, calling Restart-Computer"
    Restart-Computer -Force
  } else {
    Write-Host "A reboot is needed but the option to automatically reboot was not used. Please perform a reboot manually"
  }
}

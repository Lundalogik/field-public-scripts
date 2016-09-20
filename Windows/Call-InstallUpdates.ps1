param( [switch] $OptionalUpdates )

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
checkForPendingReboot

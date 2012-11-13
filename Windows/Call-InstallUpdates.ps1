$ScriptDir = $MyInvocation.MyCommand.Path | split-path
Set-Alias registerTask $ScriptDir\Register-TaskForWindowsUpdate.ps1
Set-Alias getTask $ScriptDir\Get-Task.ps1
Set-Alias checkForPendingReboot $ScriptDir\Check-ForPendingReboot.ps1
$task = registerTask
$task.Run()
do {
	sleep -Seconds 10
	$task = getTask $task.TaskName
	Write-Host ("Windows Update task is {0}" -f $task.Status)
} while( $task.Status -eq "Running" )
checkForPendingReboot
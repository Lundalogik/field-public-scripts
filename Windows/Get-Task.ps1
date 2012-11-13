<#
.SYNOPSIS
	Simple wrapper around schtasks.exe which allows you to query and run a scheduled tasks easily from PowerShell
.DESCRIPTION
	Use (Get-Task.ps1 taskname).Run() to execute a scheduled task on demand.
	Use Get-Task.ps1 without arguments to get all registered tasks.
#>
param( $taskName )
if( $taskName ) {
	$tasks = schtasks /query /fo csv /tn $taskName | ConvertFrom-Csv 
} else {
	$tasks = schtasks /query /fo csv | ?{ $_ -ne '"TaskName","Next Run Time","Status"' } | ConvertFrom-Csv -Header "TaskName", "Next Run Time", "Status"
}
$tasks | Add-Member -PassThru -MemberType ScriptMethod -Name Run -Value { schtasks /run /tn $this.TaskName | Out-Null }
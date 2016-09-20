param( [switch] $OptionalUpdates )

$ScriptDir = $MyInvocation.MyCommand.Path | split-path
Set-Alias getTask $ScriptDir\Get-Task.ps1

$OptionalUpdatesSwitch = ""
if( $OptionalUpdates ) {
  $OptionalUpdatesSwitch = "-OptionalUpdates"
}

$ST = new-object -com("Schedule.Service")
$ST.connect( $env:COMPUTERNAME )
$RootFolder = $ST.getfolder("\")
$TaskXml = @"
<?xml version="1.0" ?>
<Task xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
        <Date>$(get-date -format s)</Date>
        <Author>RemoteX Technologies</Author>
        <Version>1.0.0</Version>
        <Description>Starts Windows Update on demand which is needed to be run as SYSTEM which can't be done when invoking it over WinRM.</Description>
    </RegistrationInfo>
    <Triggers>
    </Triggers>
    <Principals>
        <Principal>
            <UserId>SYSTEM</UserId>
            <LogonType>InteractiveToken</LogonType>
        </Principal>
    </Principals>
    <Settings>
        <Enabled>true</Enabled>
        <AllowStartOnDemand>true</AllowStartOnDemand>
        <AllowHardTerminate>true</AllowHardTerminate>
    </Settings>
    <Actions>
        <Exec>
	      <Command>%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe</Command>
    	  <Arguments>-NonInteractive -Command "&amp; '.\Install-Updates.ps1' -EnableAutomaticUpdates -AllowReboot $OptionalUpdatesSwitch -Force"</Arguments>
		  <WorkingDirectory>$ScriptDir</WorkingDirectory>
        </Exec>
    </Actions>
</Task>
"@
$TASK_CREATE_OR_UPDATE = 6
$TASK_LOGON_SERVICE_ACCOUNT = 5
$taskName = "Trigger Installation of Windows Updates"
$Rootfolder.RegisterTask( $taskName, $TaskXml, $TASK_CREATE_OR_UPDATE, "NT AUTHORITY\SYSTEM", $null, $TASK_LOGON_SERVICE_ACCOUNT ) | Out-Null

# Return task object with Run() method
getTask $taskName

#
# Use any variant of Invoke-Command (with -Session or -ComputerName) to check multiple target in one command:
# Invoke-Command -Session (Get-PSSession) -FilePath Check-ForUpdates.ps1
#
# If you are using WSUS you might want to look at:
# http://blogs.technet.com/b/heyscriptingguy/archive/2012/01/16/introduction-to-wsus-and-powershell.aspx
#
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$updates = $UpdateSession.CreateUpdateSearcher().Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0") | select -ExpandProperty Updates
$updates | select Title, MsrcSeverity, @{Name="ComputerName";Expression={ $env:COMPUTERNAME }} | group MsrcSeverity,ComputerName | sort Name
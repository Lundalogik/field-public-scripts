<#
.SYNOPSIS
	Checks the current status of Windows Update
.DESCRIPTION
	Can be used to collect the current Windows Update status of many computers with a simple PowerShell command.
	Use any variant of Invoke-Command (with -Session or -ComputerName) to check multiple target in one command:
	Invoke-Command -Session (Get-PSSession) -FilePath Check-ForUpdates.ps1

	If you are using WSUS you might want to look at:
	http://blogs.technet.com/b/heyscriptingguy/archive/2012/01/16/introduction-to-wsus-and-powershell.aspx
.EXAMPLE
	
	PS> Invoke-Command -ComputerName (1..90 | %{ "web{0:2d}" -f $_ }) -FilePath .\Check-ForUpdates.ps1

	Count Name                   Group                                       PSComputerName
	----- ----                   -----                                       --------------
	    3 Important, WEB04       {@{Title=Security Update for Windows Ser... WEB04
	    1 Moderate, WEB04        {@{Title=Security Update for Windows Ser... WEB04
	    4 WEB04                  {@{Title=Update for Windows Server 2008 ... WEB04
	   16 Critical, WEB01        {@{Title=Cumulative Security Update for ... WEB01
	   16 Important, WEB01       {@{Title=Security Update for Windows Ser... WEB01
	    2 Low, WEB01             {@{Title=Security Update for Windows Ser... WEB01
	    5 Moderate, WEB01        {@{Title=Security Update for Windows Ser... WEB01
	    7 WEB01                  {@{Title=Update for Windows Server 2008 ... WEB01
	   16 Critical, WEB03        {@{Title=Cumulative Security Update for ... WEB03
	   16 Important, WEB03       {@{Title=Security Update for Windows Ser... WEB03
	    2 Low, WEB03             {@{Title=Security Update for Windows Ser... WEB03
	    5 Moderate, WEB03        {@{Title=Security Update for Windows Ser... WEB03
	    7 WEB03                  {@{Title=Update for Windows Server 2008 ... WEB03
    ...
		3 Moderate, WEB90        {@{Title=Security Update for Windows Ser... WEB90
	    2 WEB90                  {@{Title=Update for Windows Server 2008 ... WEB90
#>
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$updates = $UpdateSession.CreateUpdateSearcher().Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0") | select -ExpandProperty Updates
$updates | select Title, MsrcSeverity, @{Name="ComputerName";Expression={ $env:COMPUTERNAME }} | group MsrcSeverity,ComputerName | sort Name
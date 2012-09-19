<#
.SYNOPSIS
	Saves worksheets in an Excel workbook as CSV files
.EXAMPLE
	PS> .\Convert-ExcelToCsv.ps1 test.xlsx -filter Status*
	Saving sheet Status brandskydd månad (7 rows) to test_Status brandskydd månad.csv
	
	Saves only those sheets whose name matches the given filter

#>
param( 
	[parameter(mandatory=$true)]
	$excelFile,
	[parameter(mandatory=$false)]
	$filter = "*",
	[parameter(mandatory=$false)]
	$outputprefix,
	[parameter(mandatory=$false)]
	[Switch] $noOutput
)

# Need some Win32 functionality to get the PID of the Excel app
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class Win32Api
{
[System.Runtime.InteropServices.DllImportAttribute( "User32.dll", EntryPoint =  "GetWindowThreadProcessId" )]
public static extern int GetWindowThreadProcessId ( [System.Runtime.InteropServices.InAttribute()] System.IntPtr hWnd, out int lpdwProcessId );

[DllImport("User32.dll", CharSet = CharSet.Auto)]
public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
}
"@

$xls = gi $excelFile
$xlCSV = 6 
if(! $outputprefix ) {
	$outputprefix = $xls.FullName -replace $xls.Extension,""
}

$xl = New-Object -com "Excel.Application" 
$excelPid = [IntPtr]::Zero
[Win32Api]::GetWindowThreadProcessId( $xl.HWND, [ref] $excelPid ) | Out-Null

# Workaround for "Old type library..." bug for non-US cultures
$thread = [System.Threading.Thread]::CurrentThread
$currentCulture = $thread.CurrentCulture
$thread.CurrentCulture = New-Object System.Globalization.CultureInfo("en-US")

$xl.Application.Interactive = $false
$wb=$xl.workbooks.open($xls) 
$xl.displayalerts=$False 
$wb.Sheets | ?{ $_.Name -like $filter } | %{ 
	$csvFile = New-Object psobject -Property @{ `
		SheetName = $_.Name; `
		RowCount = $_.UsedRange.Rows.Count; `
		Path = ("{0}_{1}.csv" -f $outputprefix,$_.Name) `
	}
	Write-Host "Saving sheet $($csvFile.SheetName) ($($csvFile.RowCount) rows) to $($csvFile.Path)"
	$_.SaveAs($csvFile.Path, $xlCSV, $null, $null, $false, $false, $false)
	if(!$noOutput) {
		$csvFile
	}
}

# Discard all changes and close the file
$wb.Saved = $true
$wb.close($false)

$xl.quit() 
kill -Id $excelPid

$thread.CurrentCulture = $currentCulture

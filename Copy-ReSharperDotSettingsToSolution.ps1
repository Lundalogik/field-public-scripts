<#
.SYNOPSIS
    Adds or replace a solution's ReSharper .DotSettings file.
.DESCRIPTION
    Copies and/or replaces the ReSharper .DotSettings file for a Visual Studio solution.
.EXAMPLE
    PS C:\> .\Copy-ReSharperDotSettingsToSolution.ps1 -SolutionFilePath 'C:\Path\To\Solution.sln' -DotSettingsFilePath 'C:\Path\To\Master.sln.DotSettings'
    Copies and replaces C:\Path\To\Solution.sln.DotSettings with C:\Path\To\Master.sln.DotSettings.
.INPUTS
    You can pipe the solution file path to the cmdlet.
.OUTPUTS
    The .DotSettings file path that was copied in the cmdlet.
.NOTES
    Use the -WhatIf flag to "inspect" what the cmdlet would do if run without it.
    Use the -Verbose flag to output more information about the process.
#>

[CmdletBinding(SupportsShouldProcess)]

param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true,
               ValueFromPipelineByPropertyName = $true,
               HelpMessage = "Path to a solution (.sln) file.")]
    [Alias("FullName", "Path", "Solution", "SolutionPath")]
    [ValidateScript({ Test-Path -Include '*.sln' -Path $_ -PathType Leaf })]
    [string]
    $SolutionFilePath,

    [Parameter(Mandatory = $true,
               HelpMessage = "Path to the master .DotSettings file.")]
    [Alias("DotSettings")]
    [ValidateScript({ Test-Path -Include '*.DotSettings' -Path $_ -PathType Leaf })]
    [string]
    $DotSettingsFilePath
)

process {
    $SolutionFilePath = Resolve-Path -Path $SolutionFilePath
    $DotSettingsFilePath = Resolve-Path -Path $DotSettingsFilePath

    $DestinationFilePath = "$SolutionFilePath.DotSettings"

    if( $DotSettingsFilePath -eq $DestinationFilePath ) {
        Write-Verbose "WARNING! $DotSettingsFilePath is trying to replace itself, ignoring!"
        return;
    }

    if( $PSCmdlet.ShouldProcess($DestinationFilePath, "Copy/replace with $DotSettingsFilePath") ) {
        Write-Verbose "Copying $DotSettingsFilePath to $DestinationFilePath..."

        Copy-Item -Path $DotSettingsFilePath -Destination $DestinationFilePath -Force

        $DestinationFilePath
    }
}

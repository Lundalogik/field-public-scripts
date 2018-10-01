<#
.SYNOPSIS
    Adds a link to a CommonAssemblyInfo.cs in a project file.
.DESCRIPTION
    Checks whether a CommonAssemblyInfo.cs is linked in a Visual Studio project file and adds it if not.
    It also updates the AssemblyInfo.cs in the project directory to only contain the data necessary.
.EXAMPLE
    PS C:\> .\Set-CommonAssemblyInfoProjectReference.ps1 -ProjectFilePath 'C:\Path\To\Project.csproj' -CommonAssemblyInfoFilePath 'C:\Path\To\CommonAssemblyInfo.cs'
    Inspects the C:\Path\To\Project.csproj project file and adds a link to C:\Path\To\CommonAssemblyInfo.cs if it's not already there.
.EXAMPLE
    PS C:\> Get-ChildItem -Path 'C:\Path\To\Source\Root' -Include '*.csproj' -Recurse | .\Set-CommonAssemblyInfoProjectReference.ps1 -CommonAssemblyInfoFilePath 'C:\Path\To\CommonAssemblyInfo.cs'
    Inspects all .csproj project files in C:\Path\To\Source\Root and sub directories and adds a link to C:\Path\To\CommonAssemblyInfo.cs if it's not already there.
.INPUTS
    You can pipe the project file path to the cmdlet.
.OUTPUTS
    The project file path that was supplied to the cmdlet.
.NOTES
    Use the -WhatIf flag to "inspect" what the cmdlet would do if run without it.
    Use the -Verbose flag to output more information about the process.
#>

[CmdletBinding(SupportsShouldProcess)]

param (
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true,
               ValueFromPipelineByPropertyName = $true,
               HelpMessage = "Path to a project (.csproj) file.")]
    [Alias("FullName", "Path", "Project", "ProjectPath")]
    [ValidateScript({ Test-Path -Include '*.csproj' -Path $_ -PathType Leaf })]
    [string]
    $ProjectFilePath,

    [Parameter(Mandatory = $true,
               HelpMessage = "Path to a CommonAssemblyInfo.cs file.")]
    [Alias("CommonAssemblyInfo", "CommonAssemblyInfoPath")]
    [ValidateScript({ Test-Path -Include 'CommonAssemblyInfo.cs' -Path $_ -PathType Leaf })]
    [string]
    $CommonAssemblyInfoFilePath
)

begin {
    $AssemblyInfoUsingPattern = '^using System\.(Reflection|Runtime\.InteropServices)\;'
    $AssemblyInfoAttributePattern = '^\[assembly\: (Assembly(Description|Product|Title)|Guid)\('
}

process {
    $ProjectFilePath = Resolve-Path -Path $ProjectFilePath
    $CommonAssemblyInfoFilePath = Resolve-Path -Path $CommonAssemblyInfoFilePath

    [xml]$csproj = Get-Content -Path $ProjectFilePath
    $xmlns = $csproj.Project.GetAttribute("xmlns");

    [System.Xml.XmlNamespaceManager]$namespaceManager = $csproj.NameTable
    $namespaceManager.AddNamespace('', $xmlns);

    $files = $csproj.Project.SelectNodes( "//*[local-name() = 'Compile']", $namespaceManager )

    $assemblyInfoFile = $files | Where-Object { $_.Include -imatch '\\AssemblyInfo.cs$' } | Select-Object -First 1
    if( -not $assemblyInfoFile ) {
        Write-Verbose "$ProjectFilePath does not contain a AssemblyInfo.cs"
        return;
    }

    $commonAssemblyInfoFiles = $files | Where-Object { $_.Include -imatch '\\CommonAssemblyInfo.cs$' }
    if( $commonAssemblyInfoFiles ) {
        Write-Verbose "$ProjectFilePath already contains a CommonAssemblyInfo.cs"
        if( -not ($commonAssemblyInfoFiles | Where-Object { $_.Link }) ) {
            Write-Warning "$ProjectFilePath contains a CommonAssemblyInfo.cs but it is not linked!"
        }
        return;
    }

    $projectAssemblyInfoFileRelativePath = $assemblyInfoFile.Include
    $projectCommonAssemblyInfoFilePath = $projectAssemblyInfoFileRelativePath -ireplace '\\AssemblyInfo.cs', '\CommonAssemblyInfo.cs'
    $ProjectDirectoryPath = Split-Path -Path $ProjectFilePath -Parent

    Push-Location $ProjectDirectoryPath

    $projectAssemblyInfoFileAbsolutePath = Resolve-Path $projectAssemblyInfoFileRelativePath
    $commonAssemblyInfoRelativePath = Resolve-Path $CommonAssemblyInfoFilePath -Relative

    Pop-Location

    if( $PSCmdlet.ShouldProcess($ProjectFilePath, "Update project file") ) {
        Write-Verbose "Adding link to $CommonAssemblyInfoFilePath in $ProjectFilePath..."

        $ref = $csproj.CreateElement("Compile", $xmlns)
        $ref.SetAttribute("Include", $commonAssemblyInfoRelativePath)
        $link = $csproj.CreateElement("Link", $xmlns)
        $link.AppendChild($csproj.CreateTextNode($projectCommonAssemblyInfoFilePath)) | Out-Null
        $ref.AppendChild($link) | Out-Null
    
        $assemblyInfoFile.ParentNode.InsertAfter($ref, $assemblyInfoFile) | Out-Null

        Write-Verbose "Saving $ProjectFilePath..."

        $csproj.Save($ProjectFilePath);
    }

    if( $PSCmdlet.ShouldProcess($projectAssemblyInfoFileAbsolutePath, "Update assembly info file") ) {
        $usings = @()
        $attributes = @()
        Get-Content -Path $projectAssemblyInfoFileAbsolutePath | ForEach-Object {
            if( $_ -match $AssemblyInfoUsingPattern ) {
                $usings += $_
            } elseif ( $_ -match $AssemblyInfoAttributePattern ) {
                $attributes += $_
            }
        }
    
        $usingsString = $usings -join [System.Environment]::NewLine
        $attributesString = $attributes -join [System.Environment]::NewLine
        $content = $usingsString + [System.Environment]::NewLine + [System.Environment]::NewLine + $attributesString

        Write-Verbose "Updating $projectAssemblyInfoFileAbsolutePath..."

        $content | Set-Content -Path $projectAssemblyInfoFileAbsolutePath
    }

    $ProjectFilePath
}

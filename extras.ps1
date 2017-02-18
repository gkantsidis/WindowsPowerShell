#Requires -Modules Environment

[CmdletBinding()]
param(
    [switch]
    $DoNotLoad
)

$modules = (
    'cWindowsOS',
    'EZOut',
    'DeployImage',
    'Find-String',
    'GistProvider',
    'IsePackV2',
    'LibGit2',
    'LINQ',
    'Logman',
    'nPSDesiredStateConfiguration',
    'OutlookConnector',
    'Pipeworks',
    'PoshInternals',
    'psake',
    'PSConfig',
    'PSParallel',
    'PSScriptAnalyzer',
    'Posh-Gist',
    'RoughDraft',
    'ScriptBrowser',
    'ScriptCop',
    'ShowUI',
    'SnippetPx',
    'TypePx',
    'WindowsImageTools',
    'xNetworking'
)

$modules | ForEach-Object -Process {
    $m = $_
    Write-Verbose -Message "Examining $m"
    Get-ModuleInstall -ModuleName $m -ErrorAction SilentlyContinue

    $load = -not $DoNotLoad
    $isLoaded = (Get-Module -Name $m) -ne $null
    $isAvailable = (Get-Module $m -ListAvailable) -ne $null
    Write-Verbose -Message "Module: $m, loaded: $isLoaded, available: $isAvailable"
    if ($load -and (-not $isLoaded) -and $isAvailable) {
        Write-Verbose -Message "Importing module $m"
        Import-Module -Name $m
    }
}
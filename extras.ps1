#Requires -Modules Environment,xUtility

[CmdletBinding()]
param(
    [switch]
    $DoNotLoad
)

$modules = (
    'cWindowsOS',
    'EZOut',
    'DeployImage',
    'DockerMsftProvider',
    'Find-String',
    'GistProvider',
    'LibGit2',
    'LINQ',
    'Logman',
    'nPSDesiredStateConfiguration',
    'OutlookConnector',
    'Pipeworks',
    'Plaster',
    'PoshInternals',
    'psake',
    'PSConfig',
    'PSFzf',
    'PSParallel',
    'PSScriptAnalyzer',
    'PSWindowsUpdate',
    'Posh-Gist',
    'RoughDraft',
    'ScriptBrowser',
    'ScriptCop',
    'ShowUI',
    'SnippetPx',
    'TypePx',
    'xNetworking'
)

$modulesIse = (
    'IsePackV2'
)

$modulesAsAdmin = (
    'WindowsImageTools'
)

function ProcessModule {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [string[]]
        $module,

        [bool]
        $load
    )
    Write-Verbose -Message "Examining $module, will load? $load"
    Get-ModuleInstall -ModuleName $module -ErrorAction SilentlyContinue

    $isLoaded = (Get-Module -Name $module) -ne $null
    $isAvailable = (Get-Module $module -ListAvailable) -ne $null
    Write-Verbose -Message "Module: $module, loaded: $isLoaded, available: $isAvailable"
    if ($load -and (-not $isLoaded) -and $isAvailable) {
        Write-Verbose -Message "Importing module $module"
        Import-Module -Name $module
    }
}

$load = -not $DoNotLoad
ProcessModule -module $modules -load $load

$load = (Test-AdminRights) -and (-not $DoNotLoad)
Write-Verbose -Message "Checking modules that require admin rights"
ProcessModule -module $modulesAsAdmin -load $load

$load = ($Host.Name -eq "Windows PowerShell ISE Host") -and (-not $DoNotLoad)
Write-Verbose -Message "Checking ISE modules"
ProcessModule -module $modulesIse -load $load

if (-not (Get-Command -Name fzf -ErrorAction SilentlyContinue)) {
    Write-Verbose -Message "Cannot find fzf.exe in the path; please install, e.g. cinst -y fzf"
}
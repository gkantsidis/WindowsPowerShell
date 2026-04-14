#Requires -Modules Environment,xUtility

[CmdletBinding()]
param(
    [switch]
    $DoNotLoad
)

$modules = (
    'Configuration',
    'cWindowsOS',
    'EZOut',
    'DeployImage',
    'DockerMsftProvider',
    'GistProvider',
    'GuiCompletion',
    'InvokeBuild',
    'Logging',
    'Logman',
    'nPSDesiredStateConfiguration',
    'OutlookConnector',
    'Pester',
    'Pipeworks',
    'Plaster',
    'posh-ssh',
    'posh-with',                # Program prefixing for continuous workflow using a single tool.
    'PoshInternals',
    'PowerLine',                # Classes for richer output and prompts
    'PowerShellCookbook',
    'psake',
    'PSConfig',
    'pscx',
    'PSDepend',
    'PSFzf',
    'PSParallel',
    'PSScriptAnalyzer',
    'PSWindowsUpdate',
    'posh-git',
    'RoughDraft',
    'ScriptBrowser',
    'ScriptCop',
    'SharePointPnPPowerShellOnline',
    'ShowUI',
    'SnippetPx',
    'SpeculationControl',       # Check for Meltdown and Spectre bugs in Intel processors --- https://aka.ms/SpeculationControlPS
    'SSH',
    'VSSetup',
    'xDscDiagnostics',
    'xNetworking',
    'z'
)

$modulesIse = (
    'ISEModuleBrowserAddon',
    'IsePackV2',
    'ISEScriptAnalyzerAddOn',
	'PowerShellISEModule'
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

    $isLoaded = $null -ne (Get-Module -Name $module)
    $isAvailable = $null -ne (Get-Module $module -ListAvailable)
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

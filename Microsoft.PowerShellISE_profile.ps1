$usermodules = Join-Path -Path $PSScriptRoot -ChildPath MyModules
if ($null -eq $Env:PSModulePath) {
    $modulePaths = $Env:PSModulePath.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    if ($modulePaths -notcontains $usermodules) {
        $Env:PSModulePath += ";$usermodules"
    }
}

$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Push-Location $private:PowerShellProfileDirectory

#
# Initialization
#

Import-Module Environment

#
# Checking for external modules
# These are the external modules that we would like to have installed in the system
#
$StartMS = Get-Date

$modules = (
    'PowerShellGet',
    'PSReadLine',
    'pscx',
    'PowerShellCookbook',
    'posh-git',
    'TypePx',
    'VSSetup',
    'ISEModuleBrowserAddon'
)

Get-ModuleInstall -ModuleName $modules -ErrorAction SilentlyContinue

$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds

"{0,-50} {1,10:F3} msec to load" -f "Checking for external modules",$Diff

# The other modules are local (i.e. in the repo or in submodules):
# - Posh-VsVars (not really a module)
# - Pester
# - IsePester
# - PowerShellArsenal

#
# Build-in modules and initialization
#

Import-Module -Name powershellGet -ErrorAction SilentlyContinue

Import-Module -Name PSReadLine -ErrorAction SilentlyContinue
if (Get-Module -Name PSReadLine -ListAvailable) {
	. $PSScriptRoot\profile_readline.ps1
} else {
	Write-Warning -Message "Consider installing PSReadLine module"
}

#
# Third party installable modules
#

$StartMS = Get-Date
if (-not (Get-Module -Name pscx -ListAvailable)) {
    Write-Warning -Message "Consider installing pscx"
}
if (-not (Get-Module -Name PowerShellCookbook -ListAvailable)) {
    Write-Warning -Message "Consider installing PowerShellCookbook"
}
$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds

"{0,-50} {1,10:F3} msec to load" -f "Third party installable modules",$Diff

#
# Third party modules with special initialization
#

# Module: posh-git
$StartMS = Get-Date

# Import the posh-git module, first via installed posh-git module.
# If the module isn't installed, then attempt to load it from the cloned posh-git Git repo.
$localPoshGitModule = Join-Path -Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -ChildPath "Modules" | `
                      Join-Path -ChildPath "posh-git" | `
                      Join-Path -ChildPath "src" | `
                      Join-Path -ChildPath "posh-git.psd1"

$poshGitModule = Get-Module posh-git -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if ($poshGitModule) {
    $poshGitModule | Import-Module
}
else {
    Write-Warning "Consider installing posh-git module (as admin): Install-Module -Name posh-git -Force -AllowClobber"

    if (Test-Path -LiteralPath $localPoshGitModule) {
        Import-Module $localPoshGitModule
    }
    else {
        throw "Failed to import posh-git."
    }
}

# Settings for the prompt are in GitPrompt.ps1, so add any desired settings changes here.
# Example:
#     $Global:GitPromptSettings.BranchBehindAndAheadDisplay = "Compact"

# Start-SshAgent -Quiet # Not needed any more?

# Other modules
Invoke-Expression -Command .\MyModules\Posh-GitHub\Posh-GitHub-Profile.ps1

if (Test-HasVisualStudio) {
    Import-Module -Name .\Modules\Posh-VsVars
    Write-Warning -Message "You may want to call Set-VsVars to import Visual Studio settings"
}

$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds
"{0,-50} {1,10:F3} msec to load" -f "posh-git took",$Diff

#
# Third party modules that do not require special initialization
#

$StartMS = Get-Date

Import-Module Pester
Import-Module IsePester
# Avoid loading because it triggers security alerts
# Import-Module PowerShellArsenal

if (Test-Path -Path $env:ChocolateyInstall\helpers\chocolateyInstaller.psm1 -PathType Leaf) {
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1" -Force
}

Import-Module -Name TypePx -ErrorAction SilentlyContinue

$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds
"{0,-50} {1,10:F3} msec to load" -f "Third party modules took",$Diff

#
# Command overrides
#

$StartMS = Get-Date

. $PSScriptRoot\Overrides\Set-LocationWithHints.ps1

$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds
"{0,-50} {1,10:F3} msec to load" -f "Command overrides",$Diff

#
# Local Modules
#

$StartMS = Get-Date

Set-StrictMode -Version latest

Import-Module Editors

$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds
"{0,-50} {1,10:F3} msec to load" -f "Local Modules",$Diff

#
# End of initialization
#

Pop-Location

Write-Verbose -Message "Setting prompt"
. $PSScriptRoot\Prompts.ps1
Set-NormalPrompt -NoColor
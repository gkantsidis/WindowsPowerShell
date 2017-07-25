#
# Initialization
#

Import-Module Environment

#
# Checking for external modules
# These are the external modules that we would like to have installed in the system
#
Start-Timing

$modules = (
    'PowerShellGet',
    'PSReadLine',
    'pscx',
    'PowerShellCookbook',
    'posh-git',
    'TypePx',
    'VSSetup',
    'xUtility'
)

Get-ModuleInstall -ModuleName $modules -ErrorAction SilentlyContinue

Stop-Timing -Description "Checking for external modules"

# The other modules are local (i.e. in the repo or in submodules):
# - Editors
# - Invoke-MSBuild
# - Pester
# - IsePester
# - PowerShellArsenal
# - Posh-VsVars (not really a module)

#
# Build-in modules and initialization
#
Import-Module -Name powershellGet -ErrorAction SilentlyContinue

Import-Module -Name PSReadLine -ErrorAction SilentlyContinue
if (Get-Module -Name PSReadLine) {
    . $PSScriptRoot\profile_readline.ps1
} else {
    Write-Warning -Message "Consider installing PSReadLine module"
}

#
# Third party installable modules
#

Start-Timing
if (-not (Get-Module -Name pscx -ListAvailable)) {
    Write-Warning -Message "Consider installing pscx"
}
if (-not (Get-Module -Name PowerShellCookbook -ListAvailable)) {
    Write-Warning -Message "Consider installing PowerShellCookbook"
}
Stop-Timing -Description "Third party installable modules"

#
# Third party modules with special initialization
#

# Module: posh-git
Start-Timing

# Import the posh-git module.

$poshGitModule = Get-Module posh-git -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if ($poshGitModule) {
    $poshGitModule | Import-Module
}
else {
    Write-Warning "Consider installing posh-git module (as admin): Install-Module -Name posh-git -Force -AllowClobber"
}

# Settings for the prompt are in GitPrompt.ps1, so add any desired settings changes here.
# Example:
#     $Global:GitPromptSettings.BranchBehindAndAheadDisplay = "Compact"

Start-SshAgent -Quiet

# Other modules
Invoke-Expression -Command .\Modules\Posh-GitHub\Posh-GitHub-Profile.ps1

if (Test-HasVisualStudio) {
    Import-Module -Name .\Modules\Posh-VsVars
}

Stop-Timing -Description "posh-git took"

#
# Third party modules that do not require special initialization
#

Start-Timing

# The following three are included as submodules
Import-Module Invoke-MSBuild\Invoke-MSBuild
Import-Module Pester
Import-Module PowerShellArsenal

if (Test-Path -Path $env:ChocolateyInstall\helpers\chocolateyInstaller.psm1 -PathType Leaf) {
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1" -Force
}

# Not needed here, we have imported it above:
# Import-Module PowerShellCookbook -ErrorAction SilentlyContinue
$cwcmd = Get-Command -Name New-CommandWrapper -ErrorAction SilentlyContinue
if ($cwcmd -ne $null) {
    . .\customize-console-output.ps1
}

Import-Module -Name TypePx -ErrorAction SilentlyContinue
Import-Module $PSScriptRoot\Source\PSPKI\PSPKI

Stop-Timing -Description "Third party modules took"

#
# Command overrides
#

Start-Timing

try {
    # test that the GetCommand takes 3 argument, if not it will throw an exception and we will not overload gci
    $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Management\Get-ChildItem', [System.Management.Automation.CommandTypes]::Cmdlet, "") | Out-Null
    . $PSScriptRoot\Overrides\Get-ChildItem.ps1
}
catch {
    # do nothing; keep standard gci
}

if ((Get-Module -Name xUtility -ListAvailable) -ne $null) {
    . $PSScriptRoot\Overrides\Set-LocationWithHints.ps1
} else {
    Write-Warning -Message "Consider installing xUtility (admin):  Install-Module -Name xUtility -Force -AllowClobber"
}

$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds
Stop-Timing -Description "Command overrides"

#
# Command line fuzzy finder
#

if (Get-Module -Name PSFzf -ListAvailable -ErrorAction SilentlyContinue) {
    if (-not (Get-Module -Name PSFzf -ErrorAction SilentlyContinue)) {
        # Module PSFzf exists and it is not loaded

        if (Get-Command -Name fzf -ErrorAction SilentlyContinue) {
            Import-Module PSFzf -ArgumentList 'Ctrl+T','Ctrl+Alt+R','Alt+C','Alt+A'
        } else {
            Write-Warning -Message "Consider installing fzf, e.g. cinst -y fzf"
        }
    }
}

#
# Local Modules
#

Start-Timing

Import-Module Editors
if (Get-Module -Name Z -ListAvailable -ErrorAction SilentlyContinue) {
    Import-Module Z
}

Stop-Timing -Description "Local Modules"

#
# End of initialization
#
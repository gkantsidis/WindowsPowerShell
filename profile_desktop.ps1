#
# Initialization
#

$usermodules = Join-Path -Path $PSScriptRoot -ChildPath Modules
if ($Env:PSModulePath -ne $null) {
    if (-not $Env:PSModulePath.Contains($usermodules)) {
        $Env:PSModulePath += ";$usermodules"
    }
}

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
    'xUtility'
)

Get-ModuleInstall -ModuleName $modules -ErrorAction SilentlyContinue

$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds

"{0,-50} {1,10:F3} msec to load" -f "Checking for external modules",$Diff

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

$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds
"{0,-50} {1,10:F3} msec to load" -f "posh-git took",$Diff

#
# Third party modules that do not require special initialization
#

$StartMS = Get-Date

# The following three are included as submodules
Import-Module Invoke-MSBuild\Invoke-MSBuild
Import-Module Pester
$isIse = Test-IsIse
if ($isIse) {
    Import-Module IsePester
}
Import-Module PowerShellArsenal

if (Test-Path -Path $env:ChocolateyInstall\helpers\chocolateyInstaller.psm1 -PathType Leaf) {
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1" -Force
}

# Not needed here, we have imported it above:
# Import-Module PowerShellCookbook -ErrorAction SilentlyContinue
$cwcmd = Get-Command -Name New-CommandWrapper -ErrorAction SilentlyContinue
if ( ($cwcmd -ne $null) -and (-not $isIse) ) {
    . .\customize-console-output.ps1
}

Import-Module -Name TypePx -ErrorAction SilentlyContinue

Import-Module $PSScriptRoot\Source\PSPKI\PSPKI

$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds
"{0,-50} {1,10:F3} msec to load" -f "Third party modules took",$Diff

#
# Command overrides
#

$StartMS = Get-Date

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
"{0,-50} {1,10:F3} msec to load" -f "Command overrides",$Diff

#
# Command line fuzzy finder
# 

if (Get-Module -Name PSFzf -ListAvailable -ErrorAction SilentlyContinue) {
    if (-not (Get-Module -Name PSFzf -ErrorAction SilentlyContinue)) {
        # Module PSFzf exists and it is not loaded
        Import-Module PSFzf -ArgumentList 'Ctrl+T','Ctrl+Alt+R','Alt+C','Alt+A'
    }
}

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

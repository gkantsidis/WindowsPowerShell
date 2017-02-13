#
# Initialization
#

Import-Module Environment

#
# Build-in modules and initialization
#

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
CheckInstall-Module -ModuleName pscx -ErrorAction SilentlyContinue
if (-not (Get-Module -Name pscx)) {
    Write-Warning -Message "Consider installing pscx"
}
CheckInstall-Module -ModuleName PowerShellCookbook -ErrorAction SilentlyContinue
if (-not (Get-Module -Name PowerShellCookbook)) {
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
                                                                                                                                              
Start-SshAgent -Quiet                                                                                                                         

# Other modules
Invoke-Expression -Command .\Modules\Posh-GitHub\Posh-GitHub-Profile.ps1

if (Test-HasVisualStudio) {
    Invoke-Expression -Command .\Modules\Posh-VsVars\Posh-VsVars-Profile.ps1

    # TODO The Posh-VsVars module adds spurious entries in the LIB variable
    if ($Env:LIB) {
        $newLIB = $Env:LIB -split ';' | Where-Object -FilterScript { ($_.Length -gt 0) -and (Test-Path "$_") }
        $env:LIB = [string]::Join(';', $newLIB)
    }
}

$EndMS = Get-Date
$Diff = ($EndMS - $StartMS).TotalMilliseconds
"{0,-50} {1,10:F3} msec to load" -f "posh-git took",$Diff

#
# Third party modules that do not require special initialization
#

$StartMS = Get-Date

Import-Module Invoke-MSBuild\Invoke-MSBuild
Import-Module Pester
Import-Module IsePester
Import-Module PowerShellArsenal

if (Test-Path -Path $env:ChocolateyInstall\helpers\chocolateyInstaller.psm1 -PathType Leaf) {
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1" -Force
}

Import-Module PowerShellCookbook -ErrorAction SilentlyContinue
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

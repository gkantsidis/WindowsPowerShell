#
# Initialization
#

Import-Module Environment

#
# Build-in modules and initialization
#

Import-Module PSReadLine
Set-PSReadlineOption -EditMode Emacs
Set-PSReadlineKeyHandler -Key "Ctrl+LeftArrow" -Function ShellBackwardWord
Set-PSReadlineKeyHandler -Key "Ctrl+RightArrow" -Function ShellForwardWord

#
# Third party installable modules
#

CheckInstall-Module -ModuleName pscx

#
# Third party modules with special initialization
# 

# Module: posh-git

Invoke-Expression -Command .\Modules\posh-git\profile.example.ps1

Rename-Item Function:\Prompt PoshGitPrompt -Force
function Prompt() {
    if (Test-Path Function:\PrePoshGitPrompt) {
        ++$global:poshScope
        New-Item function:\script:Write-host -value "param([object] `$object, `$backgroundColor, `$foregroundColor, [switch] `$nonewline) " -Force | Out-Null
        $private:p = PrePoshGitPrompt
        if(--$global:poshScope -eq 0) {
            Remove-Item function:\Write-Host -Force
        }
    }
    PoshGitPrompt
}

# Other modules
Invoke-Expression -Command .\Modules\Posh-GitHub\Posh-GitHub-Profile.ps1

if (Test-HasVisualStudio) {
    Invoke-Expression -Command .\Modules\Posh-VsVars\Posh-VsVars-Profile.ps1

    # TODO The Posh-VsVars module adds spurious entries in the LIB variable
    $newLIB = $Env:LIB -split ';' |? { ($_.Length -gt 0) -and (Test-Path "$_") }
    $env:LIB = [string]::Join(';', $newLIB)
}

#
# Third party modules that do not require special initialization
#

Import-Module Invoke-MSBuild\Invoke-MSBuild
Import-Module Pester
if (Test-IsIse) {
    Import-Module IsePester
}
Import-Module PowerShellArsenal

if (Test-Path -Path $env:ChocolateyInstall\helpers\chocolateyInstaller.psm1 -PathType Leaf) {
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1" -Force
}

#
# Local Modules
# 

Set-StrictMode -Version latest

Import-Module Editors

#
# End of initialization
# 

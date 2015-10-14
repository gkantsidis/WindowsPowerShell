#
# Initialization
#

$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent 
Push-Location $private:PowerShellProfileDirectory

Import-Module Environment

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

if (Has-VisualStudio) {
    Invoke-Expression -Command .\Modules\Posh-VsVars\Posh-VsVars-Profile.ps1

    # TODO The Posh-VsVars module adds spurious entries in the LIB variable
    $newLIB = $Env:LIB -split ';' |? { ($_.Length -gt 0) -and (Test-Path "$_") }
    $env:LIB = [string]::Join(';', $newLIB)
}

#
# Third party modules that do not require special initialization
#

Import-Module Invoke-MSBuild
# TODO Import-Module Pester
# TODO Import-Module IsePester but only in ISE
Import-Module PowerShellArsenal

#
# Local Modules
# 

Set-StrictMode -Version latest

Import-Module Editors

#
# End of initialization
# 
Pop-Location

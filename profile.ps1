#
# Import external modules
# 

$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent 
Push-Location $private:PowerShellProfileDirectory

. 'Modules\posh-git\profile.example.ps1'

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

Invoke-Expression -Command .\Modules\Posh-GitHub\Posh-GitHub-Profile.ps1
Invoke-Expression -Command .\Modules\Posh-VsVars\Posh-VsVars-Profile.ps1

#
# Third party modules
#

Import-Module Invoke-MSBuild
Import-Module PowerShellArsenal

#
# Local Modules
# 

Import-Module Editors
Set-Alias -Name e -Value Get-FileInEditor

Pop-Location


#
# Initialization
#

Import-Module Environment

#
# Build-in modules and initialization
#

if (Get-Module -Name PSReadLine) {
	. $PSScriptRoot\profile_readline.ps1
} else {
	Write-Warning -Message "Consider installing PSReadLine module"
}

#
# Third party installable modules
#

CheckInstall-Module -ModuleName pscx
CheckInstall-Module -ModuleName PowerShellCookbook

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
    if ($Env:LIB) {
        $newLIB = $Env:LIB -split ';' |? { ($_.Length -gt 0) -and (Test-Path "$_") }
        $env:LIB = [string]::Join(';', $newLIB)
    }
}

#
# Third party modules that do not require special initialization
#

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

Import-Module PowerShellCookbook -ErrorAction SilentlyContinue
$cwcmd = Get-Command -Name New-CommandWrapper -ErrorAction SilentlyContinue
if ( ($cwcmd -ne $null) -and (-not $isIse) ) {
    . .\set-file-colors.ps1
}

Import-Module -Name TypePx -ErrorAction SilentlyContinue

#
# Command overrides
#

. $PSScriptRoot\Overrides\Get-ChildItem.ps1

#
# Local Modules
# 

Set-StrictMode -Version latest

Import-Module Editors

#
# End of initialization
# 

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

CheckInstall-Module -ModuleName pscx -ErrorAction SilentlyContinue
if (-not (Get-Module -Name pscx)) {
    Write-Warning -Message "Consider installing pscx"
}
CheckInstall-Module -ModuleName PowerShellCookbook -ErrorAction SilentlyContinue
if (-not (Get-Module -Name PowerShellCookbook)) {
    Write-Warning -Message "Consider installing PowerShellCookbook"
}


#
# Third party modules with special initialization
# 

# Module: posh-git

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

try {
    # test that the GetCommand takes 3 argument, if not it will throw an exception and we will not overload gci
    $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Management\Get-ChildItem', [System.Management.Automation.CommandTypes]::Cmdlet, "") | Out-Null
    . $PSScriptRoot\Overrides\Get-ChildItem.ps1    
}
catch {
    # do nothing; keep standard gci
}


#
# Local Modules
# 

Set-StrictMode -Version latest

Import-Module Editors

#
# End of initialization
# 

#
# Third party modules with special initialization
# 

# Module: posh-git
$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent 
Push-Location $private:PowerShellProfileDirectory

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
Invoke-Expression -Command .\Modules\Posh-VsVars\Posh-VsVars-Profile.ps1

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

Pop-Location

# TODO Move to separate module
function Get-OsInfo {
	param(
	    [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Connection -ComputerName $_ -Count 1 -Quiet})]
		[string[]]
		$ComputerName = "localhost"
	)

    BEGIN {}
    PROCESS {
        foreach ($computer in $ComputerName) {
	        Get-WmiObject -class Win32_OperatingSystem -ComputerName $computer
        }
    }
    END {}
}

function Get-HwInfo {
    param(
	    [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Connection -ComputerName $_ -Count 1 -Quiet})]
		[string[]]
		$ComputerName = "localhost"
	)

    BEGIN {}
    PROCESS {
        foreach ($computer in $ComputerName) {
	        Get-WmiObject -class Win32_ComputerSystem -ComputerName $computer
        }
    }
    END {}
}

function Has-VisualStudio {
	$vs = Get-ChildItem HKLM:\SOFTWARE\Microsoft\VisualStudio\[0-9]*
	-not ($vs -eq $null)
}
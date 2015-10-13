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

Import-Module Invoke-MSBuild

Pop-Location

#
# Local Functions
# 

<#
.SYNOPSIS
Opens a file with an appropriate editor.

.DESCRIPTION
The Get-FileInEditor attempts to open a file using an appropriate editor. It will guess the editor based on suffix
and various heuristics. For example, LaTeX related files open with emacs; solution and project files with VS.


.PARAMETER Filename
The name of the file to open.


.PARAMETER NoWait
Do not wait the editor to finish with the file before continuing.


.EXAMPLE

Create a new file, or open the existing main.tex file.
Get-FileInEditor main.tex

#>
function Get-FileInEditor {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Filename,

        [Switch]
        $NoWait
    )

    if ([System.String]::IsNullOrWhiteSpace($Filename)) {
        Write-Error "Name of input file cannot be null or empty."
        throw [System.ArgumentNullException] "Input file has null or empty name."
    }

    if (Test-Path -Path $Filename -PathType Container) {
        explorer $Filename
    } else {
        $o = New-Object -TypeName System.IO.FileInfo -ArgumentList $Filename

        if ($NoWait) {
            $emacsNoWait = '-n'
        } else {
            $emacsNoWait = ''
        }

        if ($o.Extension -in '.tex', '.bib') {
            emacsclient $emacsNoWait $o
        } elseif ($o.Extension -in '.c', '.h', '.cpp', '.hpp') {
            emacsclient $emacsNoWait $o
        } elseof ($o.Extension -in '.tab', '.csv', '.txt') {
            emacsclient $emacsNoWait $o
        } else {
            notepad $o
        }
    }
}

#
# Aliases and other shortcuts
#

Set-Alias -Name e -Value Get-FileInEditor
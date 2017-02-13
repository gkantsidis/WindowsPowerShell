# Make sure that %HOMEDRIVE%%HOMEPATH%\Documents\WindowsPowerShell or destination directory is in PSModulePath

$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent 
Push-Location $private:PowerShellProfileDirectory

if ($Env:VSIDE) {
    # Inside Visual Studio --- ignore all initializations
} elseif ($Host.Name -eq "Windows PowerShell ISE Host") {
    . .\profile_ise.ps1
} else {
    # Regular (desktop) mode
    Write-Verbose -Message "Calling profile_desktop.ps1"
    . .\profile_desktop.ps1
}

if (Test-Path -Path profile_local.ps1 -PathType Leaf) {
    Write-Verbose -Message "Calling profile_local.ps1"
    . .\profile_local.ps1
}

Pop-Location

# General alias
function Get-GitLog { git log --oneline --all --graph --decorate $args }
Set-alias gitlog Get-GitLog

# Shortcuts
New-PSDrive -Name me -PSProvider FileSystem -Root $Env:HOME

if (Test-Path -Path $Env:HOME\Documents\WindowsPowerShell) {
    # Normal path
    New-PSDrive -Name ps -PSProvider FileSystem -Root $Env:HOME\Documents\WindowsPowerShell
} else {
    # If the user changes the location of the Documents folder, then 
    New-PSDrive -Name ps -PSProvider FileSystem -Root $PSScriptRoot
}

Write-Verbose -Message "Settting prompt"
. $PSScriptRoot\Prompts.ps1

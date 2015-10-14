# Make sure that %HOMEDRIVE%%HOMEPATH%\Documents\WindowsPowerShell or destination directory is in PSModulePath

$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent 
Push-Location $private:PowerShellProfileDirectory

if ($Env:VSIDE) {
    # Inside Visual Studio --- ignore all initializations
} else {
    # Regular (desktop) mode
    . .\profile_desktop.ps1
}
Pop-Location
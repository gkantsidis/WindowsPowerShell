# Make sure that %HOMEDRIVE%%HOMEPATH%\Documents\WindowsPowerShell or destination directory is in PSModulePath

$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Push-Location $private:PowerShellProfileDirectory

if (Test-Path -Path profile_local.ps1 -PathType Leaf) {
    Write-Verbose -Message "Calling profile_local.ps1"
    . .\profile_local.ps1
}

Pop-Location

# Add modules for PowerShellEditorServices
$PSEditorServicesPath = Join-Path -Path $PSScriptRoot -ChildPath "Modules" | `
                        Join-Path -ChildPath "PowerShellEditorServices" |`
                        Join-Path -ChildPath "module"

if ((Test-Path -Path $PSEditorServicesPath) -and `
    (-not $Env:PSModulePath.Contains($PSEditorServicesPath)) -and `
    (-not [Environment]::GetEnvironmentVariable("PSModulePath", [EnvironmentVariableTarget]::User).Contains($PSEditorServicesPath)) -and `
    (-not [Environment]::GetEnvironmentVariable("PSModulePath", [EnvironmentVariableTarget]::Machine).Contains($PSEditorServicesPath))
    )
{
    $current = [Environment]::GetEnvironmentVariable("PSModulePath", [EnvironmentVariableTarget]::User)
    if ([string]::IsNullOrWhiteSpace($current)) {
        [Environment]::SetEnvironmentVariable("PSModulePath", $PSEditorServicesPath, [EnvironmentVariableTarget]::User)
    } else {
        $newpath = "{0};{1}" -f $current,$PSEditorServicesPath
        [Environment]::SetEnvironmentVariable("PSModulePath", $newpath, [EnvironmentVariableTarget]::User)
    }
    $Env:PSModulePath += ";$PSEditorServicesPath"
}

# General alias
function Get-GitLog { git log --oneline --all --graph --decorate $args }
Set-alias gitlog Get-GitLog

# Shortcuts
if (Get-ChildItem -Path Env:HOME -ErrorAction SilentlyContinue) {
    $MyHome = $Env:HOME
} else {
    $MyHome = $Env:HOMEDRIVE + $Env:HOMEPATH
}

New-PSDrive -Name me -PSProvider FileSystem -Root $MyHome

if (Test-Path -Path $MyHome\Documents\WindowsPowerShell) {
    # Normal path
    New-PSDrive -Name ps -PSProvider FileSystem -Root $MyHome\Documents\WindowsPowerShell
} else {
    # If the user changes the location of the Documents folder, then
    New-PSDrive -Name ps -PSProvider FileSystem -Root $PSScriptRoot
}

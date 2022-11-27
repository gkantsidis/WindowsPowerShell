#
# Add our module directory to the path
# (Not all modules will work in all editions of PS)
#
$usermodules = Join-Path -Path $PSScriptRoot -ChildPath MyModules
if ($null -ne $Env:PSModulePath) {
    $modulePaths = $Env:PSModulePath.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    if ($modulePaths -notcontains $usermodules) {
        $Env:PSModulePath += ";$usermodules"
    }
} else {
    Write-Warning -Message "Env:PSModulePath is empty!"
    $Env:PSModulePath = $usermodules
}

$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Push-Location $private:PowerShellProfileDirectory

#
# Helper methods
#
function Start-Timing {
    $global:StartMS = Get-Date
}

function Stop-Timing {
    param([string]$Description)

    $EndMS = Get-Date
    $Diff = ($EndMS - $global:StartMS).TotalMilliseconds

    "{0,-50} {1,10:F3} msec to load" -f $Description,$Diff
}

#
# Call PowerShell edition specific profile
#

$editionProfile = "Microsoft.PowerShell_{0}_profile.ps1" -f $PSEdition
$editionProfilePath = Join-Path -Path $PSScriptRoot -ChildPath $editionProfile
Write-Host "Loading profile for edition $PSEdition"

if (Test-Path -Path $editionProfilePath) {
    . $editionProfilePath
} else {
    Write-Warning -Message "No profile available for PowerShell edition: $PSEdition"
}

Remove-Item -Path Variable:editionProfile
Remove-Item -Path Variable:editionProfilePath

#
# End of PowerShell edition specific profile
#

Pop-Location

#
# OS Specific items
#

$platform = [System.Environment]::OSVersion.Platform
Write-Host "Loading profile for platform $platform"
$platformProfile = "Microsoft.PowerShell_{0}_profile.ps1" -f $platform
$platformProfilePath = Join-Path -Path $PSScriptRoot -ChildPath $platformProfile
if (Test-Path -Path $platformProfilePath) {
    . $platformProfilePath
}


Remove-Item -Path Variable:platformProfile
Remove-Item -Path Variable:platformProfilePath

#
# Some extra stuff
#

Remove-Item -Path Variable:StartMS -ErrorAction SilentlyContinue
Set-StrictMode -Version latest

if ($platform -eq "Win32NT") {
    # This runs in all cases, but it messes up the console provider in bash in Windows
    # hence we use it only in windows --- we need something equivalent for Unix.
    . $PSScriptRoot\Prompts.ps1
}

Remove-Item -Path Variable:platform
# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# The $__ variable will hold the last output
$PSDefaultParameterValues['Out-Default:OutVariable'] = '__'
try { $null = Get-Command concfg -ea stop; concfg tokencolor -n enable } catch { }

$env:PYTHONIOENCODING="utf-8"
Invoke-Expression -Command "$(thefuck --alias)"

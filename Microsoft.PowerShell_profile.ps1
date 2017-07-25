#
# Add our module directory to the path
# (Not all modules will work in all editions of PS)
#
$usermodules = Join-Path -Path $PSScriptRoot -ChildPath Modules
if ($Env:PSModulePath -ne $null) {
    $modulePaths = $Env:PSModulePath.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    if ($modulePaths -notcontains $usermodules) {
        $Env:PSModulePath += ";$usermodules"
    }
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

Remove-Item -Path Variable:platform
Remove-Item -Path Variable:platformProfile
Remove-Item -Path Variable:platformProfilePath

#
# Some extra stuff
#

Remove-Item -Path Variable:StartMS -ErrorAction SilentlyContinue
Set-StrictMode -Version latest

. $PSScriptRoot\Prompts.ps1
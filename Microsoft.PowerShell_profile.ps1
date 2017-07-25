$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Push-Location $private:PowerShellProfileDirectory

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
#
#
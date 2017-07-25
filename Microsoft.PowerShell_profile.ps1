
$editionProfile = "Microsoft.PowerShell_{0}_profile.ps1" -f $PSEdition
$editionProfilePath = Join-Path -Path $PSScriptRoot -ChildPath $editionProfile

if (Test-Path -Path $editionProfilePath) {
    . $editionProfilePath
} else {
    Write-Warning -Message "No profile available for PowerShell edition: $PSEdition"
}

Remove-Item -Path Variable:editionProfile
Remove-Item -Path Variable:editionProfilePath
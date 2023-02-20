# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

if (Get-Command -Name scoop -ErrorAction SilentlyContinue) {
  # Scoop  - rig autocompletion
  $rig_ac=$(try { Join-Path -Path $(scoop prefix rig) -ChildPath _rig.ps1 } catch { '' })
  if (Test-Path -Path $rig_ac)  { & $rig_ac }
}

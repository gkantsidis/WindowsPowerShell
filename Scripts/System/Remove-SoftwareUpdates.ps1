#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess=$true)]
param(
)

$location = Join-Path -Path $Env:systemroot -ChildPath SoftwareDistribution
$now = Get-Date
$newname = "SoftwareDistribution-{0}" -f ($now.ToString("yyyMMdd_hhmm"))
$newlocation = Join-Path $Env:systemroot -ChildPath $newname

if ($PSCmdlet.ShouldProcess("Windows Update Service", "Stopping service")) {
    net stop wuauserv
    if ($LASTEXITCODE -ne 0) {
        Write-Error -Message "Cannot stop Windows Update service"
        return
    }
}

Rename-Item -Path $location -NewName $newname

if ($PSCmdlet.ShouldProcess("Windows Update Service", "Starting service")) {
    net start wuauserv
    if ($LASTEXITCODE -ne 0) {
        Write-Error -Message "Cannot stop Windows Update service"
        return
    }
}

Remove-Item -Path $newlocation -Recurse -Force
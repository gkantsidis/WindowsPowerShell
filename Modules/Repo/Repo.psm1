$gitCommand = Get-Command -Name git -ErrorAction SilentlyContinue
if ($gitCommand -eq $null) {
    Write-Error -Message "Cannot find git command; some functionality may not work."
}

. $PSScriptRoot/Repo.ps1
. $PSScriptRoot/Commands.ps1
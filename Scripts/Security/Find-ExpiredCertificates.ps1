[CmdletBinding()]
param(
    [DateTime]$Date = (Get-Date)
)

$stores = @("Cert:\CurrentUser\My", "Cert:\LocalMachine\My", "Cert:\CurrentUser\Root", "Cert:\LocalMachine\Root")
$expiredCerts = @()
foreach ($store in $stores) {
    Write-Verbose "Checking store: $store"
    $expiredCerts += Get-ChildItem -Path $store | Where-Object { $_.NotAfter -lt $Date } | Select-Object NotAfter, PSParentPath, Subject, Issuer
}

$expiredCerts = $expiredCerts | Sort-Object -Property NotAfter

return $expiredCerts

# Maybe renew some with:
# certutil -pulse
# dsregcmd /refreshprt

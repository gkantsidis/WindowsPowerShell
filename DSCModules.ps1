#requires -RunAsAdministrator
#Requires -Modules Environment,xUtility

[CmdletBinding()]
param(
)

$modules = (
    'cChoco',
    'vscode',
    'xPendingReboot'
)

foreach ($module in $modules) {
    Write-Verbose -Message "Checking module $module"
    Install-Module $module
}
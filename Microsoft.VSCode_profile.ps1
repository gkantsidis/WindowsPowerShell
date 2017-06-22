<#
 # Customizations for Visual Studio Code integrated PowerShell
 #>

$usermodules = Join-Path -Path $PSScriptRoot -ChildPath Modules
if ($Env:PSModulePath -ne $null) {
    if (-not $Env:PSModulePath.Contains($usermodules)) {
        $Env:PSModulePath += ";$usermodules"
    }

    $PSEditorServicesPath = Join-Path -Path $PSScriptRoot -ChildPath "Modules" | `
                        Join-Path -ChildPath "PowerShellEditorServices" |`
                        Join-Path -ChildPath "module"
    if (-not $Env:PSModulePath.Contains($PSEditorServicesPath)) {
        $Env:PSModulePath += ";$PSEditorServicesPath"
    }
}

Import-Module -Name VSCodeExtensionsCG

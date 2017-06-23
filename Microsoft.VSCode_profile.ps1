<#
 # Customizations for Visual Studio Code integrated PowerShell
 #>

$usermodules = Join-Path -Path $PSScriptRoot -ChildPath Modules
$vscmodules = Join-Path -Path $PSScriptRoot -ChildPath Modules-VSCode
$PSEditorServicesPath = Join-Path -Path $PSScriptRoot -ChildPath "Modules-VSCode" | `
                        Join-Path -ChildPath "PowerShellEditorServices" |`
                        Join-Path -ChildPath "module"

if ($Env:PSModulePath -ne $null) {
    $modules = $Env:PSModulePath.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    if ($modules -notcontains $usermodules) {
        $Env:PSModulePath += ";$usermodules"
    }
    if ($modules -notcontains $vscmodules) {
        $Env:PSModulePath += ";$vscmodules"
    }

    if ($modules -notcontains $PSEditorServicesPath) {
        $Env:PSModulePath += ";$PSEditorServicesPath"
    }
} else {
    $Env:PSModulePath = "$usermodules;$PSEditorServicesPath;$vscmodules"
}

Import-Module -Name VSCodeExtensionsCG

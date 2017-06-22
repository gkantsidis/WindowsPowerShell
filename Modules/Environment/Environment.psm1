#
# Include all files that compose the module
#

$RootOfPowershellDirectory = $PSScriptRoot

. $PSScriptRoot/Modules.ps1
. $PSScriptRoot/MsiHelper.ps1
. $PSScriptRoot/FileSystem.ps1
. $PSScriptRoot/DateTime.ps1
. $PSScriptRoot/Scoop.ps1
. $PSScriptRoot/Settings.ps1
. $PSScriptRoot/SoftwareInfo.ps1
. $PSScriptRoot/SystemInfo.ps1
. $PSScriptRoot/TextFile.ps1
. $PSScriptRoot/Windowing.ps1
. $PSScriptRoot/Debuggers.ps1
. $PSScriptRoot/Calendar.ps1
. $PSScriptRoot/Get-PendingReboot.ps1
. $PSScriptRoot/Security.ps1

if ($psEditor) {
    Register-EditorCommand `
        -Name "Environment.GetHardwareInfo" `
        -DisplayName "Get information about the hardware of the machine" `
        -ScriptBlock {
            param([Microsoft.PowerShell.EditorServices.Extensions.EditorContext]$context)
            $hw = Get-HwInfo
            Write-Output "$($hw.Name).$($hw.Domain): $($hw.Manufacturer) $($hw.Model)"
        }
}
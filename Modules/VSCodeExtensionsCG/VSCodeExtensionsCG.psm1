<#
 #
 #>

. $PSScriptRoot/GeneralInfo.ps1

if ($psEditor) {
    Register-EditorCommand `
        -Name "Environment.GetHardwareInfo" `
        -DisplayName "Get information about the hardware of the machine" `
        -Function Get-CGVSCHardwareInfo

    Register-EditorCommand `
        -Name "Repo.Status" `
        -DisplayName "Status of current repository" `
        -Function Get-CGVSCSourceInformation
}
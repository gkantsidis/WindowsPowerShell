#Requires -Module xUtility

<#PSScriptInfo

.VERSION 1.0

.GUID 4ae2a366-1703-4f62-bba0-640edd52d7ae

.AUTHOR Christos Gkantsidis

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
 Functions to check the local system 

#>
function Check-RemoteService {
    [CmdletBinding()]
    Param(
    )

    $service = Get-Service -Name WinRM -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Error -Message "Cannot find service WinRM"
    } else {
        if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
            Write-Verbose -Message "WinRM is enabled"
            return $true
        } else {
            $publicnetworks = Get-NetConnectionProfile | `
                              Where-Object -Property NetworkCategory -EQ -Value [Microsoft.PowerShell.Cmdletization.GeneratedTypes.NetConnectionProfile.NetworkCategory]::Public

            if ($publicnetworks -ne $null) {
                Write-Warning -Message "There are network interfaces with public profiles, winrm cannot be enabled"
                Write-Warning -Message "Consider changing them to private:"
                if (-not (Test-AdminRights)) { Write-Warning -Message "(with administrator rights)" }
                $publicnetworks | ForEach-Object -Process {
                    $id = $_.InterfaceIndex
                    $name = $_.Name
                    Write-Warning -Message "For interface $name : Set-NetConnectionProfile -InterfaceIndex $id -NetworkCategory Private"
                }

                return $false
            } else {
                Write-Verbose -Message "Enabling WinRM service"
                Enable-PSRemoting -Force
                $service = Get-Service -Name WinRM -ErrorAction SilentlyContinue
                return ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running)
            }
        }
    }
}

$result = @{}
$result.WinRm = (Check-RemoteService)

$result
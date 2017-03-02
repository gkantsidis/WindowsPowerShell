
<#PSScriptInfo

.VERSION 1.0

.GUID 0b3c3a39-d18e-4242-9a3a-e9491856f84f

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
 Set WinDbg as the post-mortem debugger 

#>

function Set-SystemDebugger {
    [CmdletBinding()]
    param(
        [string]
        [ValidateSet('windbg', 'default')]
        $Debugger
    )

    switch ($Debugger) {
        'windbg' { 
            $windbg = Get-Command -Name windbg -ErrorAction SilentlyContinue
            if ($windbg -eq $null) {
                Write-Error -Message "Cannot find windbg in the path. Debugger will not change"
            } else {
                if (Test-AdminRights) {
                    windbg /I
                } else {
                    Invoke-ElevatedCommand -Scriptblock { windbg /I }
                }
            }

        }
        'default' {
            if (Test-AdminRights) {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug\" -Name Debugger `
                                 -Value '"drwtsn32 -p %ld -e %ld -g"' | Out-Null
            } else {
                Invoke-ElevatedCommand -Scriptblock {
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug\" -Name Debugger `
                                    -Value '"drwtsn32 -p %ld -e %ld -g"' | Out-Null
                }
            }
        }
        Default {
            if (Test-AdminRights) {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug\" -Name Debugger `
                                 -Value '"drwtsn32 -p %ld -e %ld -g"' | Out-Null
            } else {
                Invoke-ElevatedCommand -Scriptblock {
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug\" -Name Debugger `
                                    -Value '"drwtsn32 -p %ld -e %ld -g"' | Out-Null
                }
            }
        }
    }
}

function Get-SystemDebugger {
    Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug\" -Name Debugger
}

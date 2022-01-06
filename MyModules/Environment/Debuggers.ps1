
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
        [ValidateSet('windbg', 'vsjit', 'default')]
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
        'vsjit' {
            if (Test-AdminRights) {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug\" -Name Debugger `
                                 -Value '"C:\WINDOWS\system32\vsjitdebugger.exe" -p %ld -e %ld' | Out-Null
            } else {
                Invoke-ElevatedCommand -Scriptblock {
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug\" -Name Debugger `
                    -Value '"C:\WINDOWS\system32\vsjitdebugger.exe" -p %ld -e %ld' | Out-Null
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

<#
.SYNOPSIS
Get the default debugger used by the system.

.DESCRIPTION
Returns the command used to debug failures in the system.

.EXAMPLE
Get the current debugger
  Get-SystemDebugger
#>
function Get-SystemDebugger {
    Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug\" -Name Debugger
}


<#
.SYNOPSIS
Enables debugging of loading problems of .NET applications and libraries.

.DESCRIPTION
This collects detailed  information when loading managed applications and libraries.
In case of a loading error, it will be possible to get precise information about the
location of the error (using the fusion field in the inner exception), and
from the logs, typically under the c:\FusionLog directory.

.PARAMETER LogPath
Path where to keep the logs of library loading

.EXAMPLE
Enable logging of managed loading:
  Enable-DotNetLoadingDebugging

Reproduce the loading problem and keep the detailed statistics.

Disable logging:
  Disable-DotNetLoadingDebugging

.NOTES
This slows down the system quite a bit; do not forget to delete.
#>
function Enable-DotNetLoadingDebugging {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = (Join-Path -Path (Split-Path -Parent ([Environment]::GetFolderPath("Windows"))) -ChildPath "FusionLog")
    )

    if (Test-AdminRights) {
        Set-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name EnableLog -Value 1 -Type Dword
        Set-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name ForceLog -Value 1 -Type Dword
        Set-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogFailures -Value 1 -Type Dword
        Set-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogResourceBinds -Value 1 -Type Dword
        Set-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogPath -Value $LogPath -Type String

        Write-Verbose -Message "Look for errors in $LogPath"
    } else {
        Write-Error -Message "Should run with Admin privileges"
    }
}

<#
.SYNOPSIS
Disables monitoring of loading of managed applications.

.DESCRIPTION
Disables the detailed logging of loading problems for managed code.

.EXAMPLE
Enable logging of managed loading:
  Enable-DotNetLoadingDebugging

Reproduce the loading problem and keep the detailed statistics.

Disable logging:
  Disable-DotNetLoadingDebugging
#>
function Disable-DotNetLoadingDebugging {
    if (Test-AdminRights) {
        Remove-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name ForceLog
        Remove-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogFailures
        Remove-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogResourceBinds
        Remove-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogPath
    } else {
        Write-Error -Message "Should run with Admin privileges"
    }
}

<#
.SYNOPSIS
Delete the log files when logging errors for managed applications.

.DESCRIPTION
Delete the directory where we keep the detailed log files.
The script does not check whether this is a valid directory of logs,
so it will delete everything.

.EXAMPLE
Delete the logs with
  Clear-FusionLogs
#>
function Clear-FusionLogs {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$LogPath = (Join-Path -Path (Split-Path -Parent ([Environment]::GetFolderPath("Windows"))) -ChildPath "FusionLog")
    )

    if (Test-AdminRights) {
        Remove-Item -Path "$LogPath\*" -Recurse -Force
    } else {
        Write-Error -Message "Should run with Admin privileges"
    }
}
#-------------------------------------------------------------------------
# <copyright file="Check-MS17-010-Installed.ps1" company="Microsoft">
#     Copyright (c) Microsoft Corporation.  All rights reserved.
# </copyright>
#-------------------------------------------------------------------------

<#
    .SYNOPSIS
        Checks if patches related to Microsoft Security Bulletin MS17-010 are installed
    
    .DESCRIPTION
        Scans computer for all known related patches and reports if they are installed.
    
    .PARAMETER ComputerName
        The name of the computer to scan..
    
    .EXAMPLE
        PS C:\> .Check-MS17-010-Installed.ps1 -ComputerName $remoteComputer

    .NOTES
        https://support.microsoft.com/en-us/help/4013389/title
        KB4012212 March 2017 Security Only Quality Update for Windows 7 SP1 and Windows Server 2008 R2 SP1
        KB4012213 March 2017 Security Only Quality Update for Windows 8.1 and Windows Server 2012 R2
        KB4012214 March 2017 Security Only Quality Update for Windows Server 2012
        KB4012215 March 2017 Security Monthly Quality Rollup for Windows 7 SP1 and Windows Server 2008 R2 SP1
        KB4012216 March 2017 Security Monthly Quality Rollup for Windows 8.1 and Windows Server 2012 R2
        KB4012217 March 2017 Security Monthly Quality Rollup for Windows Server 2012
        KB4012598 MS17-010: Description of the security update for Windows SMB Server: March 14, 2017
        KB4012606 March 14, 2017�KB4012606 (OS Build 17312)
        KB4013198 March 14, 2017�KB4013198 (OS Build 830)
        KB4013429 March 13, 2017�KB4013429 (OS Build 933)

        http://www.catalog.update.microsoft.com/Search.aspx?q=KB4015217
        KB4015217 April 8, 2017 Cumulative Update for Windows 10 and Windows Server 2016

        https://support.microsoft.com/en-us/help/4015549/windows-7-windows-server-2008-r2-sp1-update-kb4015549
        KB4015549 April 11, 2017�KB4015549 (Monthly Rollup)

        http://www.catalog.update.microsoft.com/Search.aspx?q=KB4015550
        KB4015550 April, 2017 Security Monthly Quality Rollup for Windows Server 2012 R2 and Windows 8.1

        https://support.microsoft.com/en-us/help/4015551/windows-server-2012-update-kb4015551
        KB4015551 April 11, 2017�KB4015551 (Monthly Rollup)

        https://support.microsoft.com/en-us/help/4016871/windows-10-update-kb4016871
        http://www.catalog.update.microsoft.com/Search.aspx?q=KB4016871
        KB4016871 May 6, 2017 Cumulative Update for Windows 10 Version 1703

        https://support.microsoft.com/en-us/help/4019213/windows-8-update-kb4019213
        KB4019213 May 9, 2017�KB4019213 (Security-only update)

        https://support.microsoft.com/en-us/help/4019215/windows-8-update-kb4019215
        KB4019215 May 9, 2017�KB4019215 (Monthly Rollup)

        https://support.microsoft.com/en-us/help/4019216/windows-server-2012-update-kb4019216
        KB4019214 May 9, 2017�KB4019216 (Monthly Rollup)

        https://support.microsoft.com/en-us/help/4019216/windows-server-2012-update-kb4019216
        KB4019216 May 9, 2017�KB4019216 (Monthly Rollup)

        https://support.microsoft.com/en-us/help/4019264/windows-7-update-kb4019264
        KB4019264 May 9, 2017�KB4019264 (Monthly Rollup)

        http://www.catalog.update.microsoft.com/Search.aspx?q=KB4019472
        KB4019472 Cumulative Update for Windows 10 and Windows Server 2016


    KB4019472 KB4015217 KB4016635 KB4015438 KB4013429 KB4012606 KB4019474 KB4019473 - Windows 10 and Windows Server 2016 
    KB4012212 KB4012215 - Windows 7
    KB4012212 KB4012215 KB4012218 KB4012598 KB4015552 KB4019263 KB4019264 - Windows 2008R2
    KB4012598 KB4013389 - Windows Server 2008
    KB4012213 KB4012216 - Windows 8.1
    KB4012213 KB4012216 KB4015549 KB4015550 KB4019213 KB4019215 - Windows 2012R2
    KB4012214 KB4012217 KB4012220 KB4015551 KB4015553 KB4015554 KB4019214 KB4019216 - Windows 2012 
#>

[CmdletBinding()]
param(
        [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [Alias("CN","Computer")]
        [String[]]$ComputerName="$env:COMPUTERNAME",
        [String]$ErrorLog,

        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        $ExtraParameters
        )


Begin {
    $windows10MajorVersion = 10
    $windows10R2BuildNumber = 15063
    $hotfixes = "KB4012212","KB4012213","KB4012214","KB4012215","KB4012216","KB4012217","KB4012218","KB4012220","KB4012598","KB4012606","KB4013389","KB4013429","KB4015217","KB4015438","KB4015549","KB4015550","KB4015551","KB4015552","KB4015553","KB4015554","KB4016635","KB4019213","KB4019214","KB4019215","KB4019216","KB4019263","KB4019264","KB4019472","KB4019474","KB4019473", "KB4016871"
}

Process {
    foreach($Computer in $ComputerName) {
        if ($Computer -eq $env:COMPUTERNAME) {
            $check = `
                @{
                    ComputerName = $env:COMPUTERNAME
                    OS = Get-WmiObject -Class Win32_OperatingSystem
                    OsMajorVersion = [Environment]::OSVersion.Version.Major
                    BuildNumber = [Environment]::OSVersion.Version.Build
                    HotFix = Get-HotFix
                }
        } else {
            return $ExtraParameters
            $check = Invoke-Command -ComputerName $Computer @ExtraParameters -ScriptBlock {
                @{
                    ComputerName = $env:COMPUTERNAME
                    OS = Get-WmiObject -Class Win32_OperatingSystem
                    OsMajorVersion = [Environment]::OSVersion.Version.Major
                    BuildNumber = [Environment]::OSVersion.Version.Build
                    HotFix = Get-HotFix
                }
            }
        }

        Write-Verbose -Message "$Computer : $($check.OS.Caption) [$($check.OS.Version)]"

        if (($check.OsMajorVersion -ge $windows10MajorVersion) -and ($check.BuildNumber -ge $windows10R2BuildNumber))
        {
            Write-Verbose -Message "$Computer is running Windows 10 RS2 and does not require patching"

            [PSCustomObject]@{
                ComputerName = $Computer
                Bulleting    = "MS17-10"
                Vulnerable   = $false
            }
        }
        else
        {            
            $hotfix = $check.HotFix | ForEach-Object {
                $id = $_.HotfixID
                if($hotfixes -contains $id) { $id }
            }

            if($hotfix.Count -eq 0) 
            {
                Write-Verbose -Message "$name is vulnerable for MS17-010. Please make sure this machine gets patched." -ForegroundColor Red
                [PSCustomObject]@{
                    ComputerName = $Computer
                    Bulleting    = "MS17-10"
                    Vulnerable   = $true
                }
            } 
            else 
            {
                Write-Verbose -Message "$name is not vulnerable for MS17-010." -ForegroundColor Green
                [PSCustomObject]@{
                    ComputerName = $Computer
                    Bulleting    = "MS17-10"
                    Vulnerable   = $true
                }                
            }
        }
    }
}

End {

}
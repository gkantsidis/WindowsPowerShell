
function Get-ListOfLogons {
    [CmdletBinding()]
    param()

    $events = Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" | Where-Object -Property Id -EQ -Value 1149
    foreach ($event in $events) {
        $ip = $event.Properties[2].Value

        $objSID = New-Object System.Security.Principal.SecurityIdentifier($event.UserId)
        $objUser = $objSID.Translate( [System.Security.Principal.NTAccount])
        $logonUser = $objUser.Value

        if ($events[0].Message -match "User:(.*)") {
            $user = $Matches[0].Replace("User: ", "").Trim()
        } else {
            $user = "<unknown>"
        }

        $result = @{
                Time = $event.TimeCreated
                LogonId = $logonUser
                UserName = $user
        }

        if ($ip.Contains(':')) {
            # this is likely an ipv6 address
            if ($ip.Contains('%')) {
                $ip = $ip.Substring(0, $ip.IndexOf('%')).Trim()
            }

            $result + @{
                IP = [System.Net.IPAddress]::Parse($ip)
            }
        } else {
            $whois = (Invoke-RestMethod "http://whois.arin.net/rest/ip/$ip")
            $netName = $whois.net.name
            $netOrg = $whois.net.orgref.name

           $result + @{
                IP = [System.Net.IPAddress]::Parse($ip)
                NetworkName = $netName
                Organization = $netOrg
            }
        }
    }
}

Function Get-WinlogonHistory
{

<#
.SYNOPSIS
Retrieves the date/time that users logged on and logged off on the system.
Author: Jacob Soo (@jacobsoo)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None
.DESCRIPTION
Retrieves the date/time that users logged on and logged off on the system.
.EXAMPLE
PS C:\>Get-WinlogonHistory
Description
-----------
Retrieves the date/time that users logged on and logged off on the system.
.NOTES
Adapted from https://raw.githubusercontent.com/jacobsoo/PowerShellArsenal/master/Forensics/Get-Winlogon-View.ps1
#>

    $UserProperty = @{n="User";e={(New-Object System.Security.Principal.SecurityIdentifier $_.ReplacementStrings[1]).Translate([System.Security.Principal.NTAccount])}}
    $TypeProperty = @{n="Action";e={if($_.EventID -eq 7001) {"Logon"} else {"Logoff"}}}
    $TimeProperty = @{n="Time";e={$_.TimeGenerated}}
    $Results = Get-EventLog System -Source Microsoft-Windows-Winlogon | Select-Object $UserProperty,$TypeProperty,$TimeProperty
    Write-Output $Results
}

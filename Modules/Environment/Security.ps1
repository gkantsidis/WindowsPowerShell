
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
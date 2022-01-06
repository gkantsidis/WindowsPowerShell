#Requires -Version 5.0

class WebProxySettings {
    [ValidateNotNullOrEmpty()]
    [string]$Protocol

    [ValidateNotNullOrEmpty()]
    [string]$Server

    [ValidateNotNullOrEmpty()]
    [int]$Port

    [bool]$Enabled = $true

    WebProxySettings([string] $Protocol, [string]$Server, [int]$Port, [bool]$Enabled = $true)
    {
        $this.Protocol = $Protocol
        $this.Server = $Server
        $this.Port = $Port
    }

    [string] ToString()
    {
        if ($this.Enabled) {
            return "{0}={1}:{2}" -f $this.Protocol,$this.Server,$this.Port
        } else {
            return "[disabled] {0}={1}:{2}" -f $this.Protocol,$this.Server,$this.Port
        }
    }
}

function Get-WebProxy {
    [CmdletBinding()]
    param (
    )

    $configurationPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $internetSettings = Get-ItemProperty -Path $configurationPath
    $proxyConfiguration = $internetSettings.ProxyServer

    if([string]::IsNullOrWhiteSpace($proxyConfiguration)) {
        Write-Verbose -Message "Proxy is not configured"
        return
    }

    [string[]]$proxies = $proxyConfiguration.Split(';')
    foreach($proxy in $proxies) {
        $tokens = $proxy.Split(@("=",":"))
        if ($tokens.Length -ne 3) {
            throw "Cannot parse string: $proxy"
            continue
        }
        else {
            $protocol = $tokens[0]
            $server = $tokens[1]
            $port = $tokens[2]

            if (($internetSettings.ProxyEnable -eq 0) -and
                ($internetSettings."ProxyHttp1.1" -eq 0)
            ) {
                $enabled = $false
            } else {
                $enabled = $true
            }

            [WebProxySettings]::new($protocol, $server, $port, $enabled)
        }
    }
}
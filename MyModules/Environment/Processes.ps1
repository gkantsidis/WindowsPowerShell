function Restart-Process {
    [CmdletBinding(DefaultParameterSetName = "ById", SupportsShouldProcess=$true)]
    param(
        [Parameter(ParameterSetName = "ById")]
        [int]$Id,

        [Parameter(ParameterSetName = "ByName")]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [switch]$Foreground,
        [switch]$Wait
    )

    switch($PsCmdlet.ParameterSetName)
    {
        "ById" {
            [System.Diagnostics.Process[]]$process = Get-Process -Id $Id -ErrorAction SilentlyContinue
            [string]$query = "ProcessId = '{0}'" -f $Id
        }

        "ByName" {
            [System.Diagnostics.Process[]]$process = Get-Process -Name $Name -ErrorAction SilentlyContinue
            [string]$query = "Name like '%{0}%'" -f $Name
        }
    }

    if (($process -eq $null) -or ($process.Length -eq 0)) {
        throw "Cannot find process"
    }
    if ($process.Length -gt 1) {
        throw "Multiple processes found --- restarting many processes is not supported yet"
    }

    [Object[]]$wmi = Get-WmiObject -Class Win32_Process -Filter $query
    if (($wmi -eq $null) -or ($wmi.Length -eq 0)) {
        throw "Cannot find WMI object for process"
    }
    if ($wmi.Length -gt 1) {
        throw "Multiple WMI objects found --- restarting many processes is not supported yet"
    }

    $process = $process[0]
    $wmi = $wmi[0]

    Write-Verbose -Message "Process $($process.Id) with command line: $($wmi.CommandLine)"
    Stop-Process -Id $process.Id

    if ($Wait) {
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        Write-Host ""
    }

    $executable = $wmi.ExecutablePath.Trim()
    if ($wmi.CommandLine.Contains($executable)) {
        $arguments = $wmi.CommandLine.Replace($wmi.ExecutablePath, "")
    } else {
        $cmdline = $wmi.CommandLine.Replace("/", "\")
        $arguments = $cmdline.Replace($wmi.ExecutablePath, "").Trim()
    }

    Write-Debug -Message "Properties:`nExecutable: $executable`nArguments : $arguments"

    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Re-starting process")) {
        if ($Foreground) {
            Invoke-Expression -Command $wmi.CommandLine
        } else {
            Start-Process -NoNewWindow -FilePath $executable -ArgumentList $arguments
        }
    }
}

function bg() {Start-Process -NoNewWindow @args}
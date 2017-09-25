#Requires -RunAsAdministrator

<#
    .SUMMARY
    Resets the Windows Update server

    .NOTES
    Instructions in https://support.microsoft.com/en-us/help/971058/how-do-i-reset-windows-update-components
 #>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$RemoveFiles,
    [switch]$AutomaticRestart
)

$services = @(
    "bits"
    "wuauserv"
    "appidsvc"
    "cryptsvc"
)

$folders = @(
    @{ Location = $Env:systemroot; Path = "SoftwareDistribution" }
    @{ Location = (Join-Path -Path $Env:systemroot -ChildPath system32); Path = "catroot2" }
)

$extra_services = @(
    "atl.dll"
    "urlmon.dll"
    "mshtml.dll"
    "shdocvw.dll"
    "jscript.dll"
    "vbscript.dll"
    "scrrun.dll"
    "msxml.dll"
    "msxml3.dll"
    "msxml6.dll"
    "actxprxy.dll"
    "softpub.dll"
    "wintrust.dll"
    "dssenh.dll"
    "rsaenh.dll"
    "gpkcsp.dll"
    "sccbase.dll"
    "slbcsp.dll"
    "cryptdlg.dll"
    "oleaut32.dll"
    "ole32.dll"
    "shell32.dll"
    "initpki.dll"
    "wuapi.dll"
    "wuaueng.dll"
    "wuaueng1.dll"
    "wucltui.dll"
    "wups.dll"
    "wups2.dll"
    "wuweb.dll"
    "qmgr.dll"
    "qmgrprxy.dll"
    "wucltux.dll"
    "muweb.dll"
    "wuwebv.dll"
)

$now = Get-Date
$now_string = $now.ToString("yyyMMdd_hhmm")

# Step 2 from Microsoft Guide
Stop-Service -Name $services -Force

# Step 3 from Microsoft Guide
$qmgr_path = Join-Path -Path $Env:ALLUSERSPROFILE -ChildPath "Application Data" | `
            Join-Path -ChildPath Microsoft | `
            Join-Path -ChildPath Network | `
            Join-Path -ChildPath Downloader
if (Test-Path -Path $qmgr_path -PathType Container) {
    Remove-Item -Path $qmgr_path -Filter qmgr*.dat
}

# Step 4 from Microsoft Guide --- optional
if ($RemoveFiles) {
    foreach ($folder in $folders) {
        $location = Join-Path -Path $folder.Location -ChildPath $folder.Path
        $newname = "{0}-{1}" -f $folder.Path,$now_string

        Write-Verbose -Message "Renaming $location to $newname"
        Rename-Item -Path $location -NewName $newname
    }

    if ($PSCmdlet.ShouldProcess("Bits service", "reset")) {
        sc.exe sdset bits "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
        sc.exe sdset wuauserv "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
    }
}

# Steps 5&6 from Microsoft Guide
Push-Location (Join-Path -Path $Env:windir -ChildPath "system32")
foreach ($svc in $extra_services) {
    if ($PSCmdlet.ShouldProcess("Service: $svc", "registering")) {
        if (Test-Path -Path $svc) {
            regsvr32.exe /s $svc
        } else {
            Write-Warning -Message "Cannot find $svc"
        }
    }
}
Pop-Location

# Steps 7&8 from Microsoft Guide
if ($PSCmdlet.ShouldProcess("Winsock", "reset")) {
    netsh winsock reset
    netsh winhttp reset proxy
}

Start-Service -Name $services

foreach ($folder in $folders) {
    $newname = "{0}-{1}" -f $folder.Path,$now_string
    $location = Join-Path -Path $folder.Location -ChildPath $newname

    Write-Verbose -Message "Deleting $location"
    if (Test-Path -Path $location -PathType Container) {
        Remove-Item -Path $location -Recurse -Force
    }
}

if ($PSCmdlet.ShouldProcess("Machine: $($Env:COMPUTERNAME)", "reboot")) {
    Write-Warning -Message "You need to reboot your machine now"
}

if ($AutomaticRestart) {
    Restart-Computer
}
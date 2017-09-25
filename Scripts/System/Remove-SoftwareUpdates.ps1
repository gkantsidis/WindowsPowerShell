#Requires -RunAsAdministrator

<#
    .SUMMARY
    Resets the Windows Update server

    .NOTES
    Instructions in https://support.microsoft.com/en-us/help/971058/how-do-i-reset-windows-update-components
 #>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
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

foreach ($service in $services) {
    Write-Verbose -Message "Stopping service: $service"
    if ($PSCmdlet.ShouldProcess("Service: $service", "Stopping service")) {
        net stop $service
        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message "Cannot stop service: $service"
            # return
        }
    }
}

$qmgr_path = Join-Path -Path $Env:ALLUSERSPROFILE -ChildPath "Application Data" | `
             Join-Path -ChildPath Microsoft | `
             Join-Path -ChildPath Network | `
             Join-Path -ChildPath Downloader
if (Test-Path -Path $qmgr_path -PathType Container) {
    Remove-Item -Path $qmgr_path -Filter qmgr*.dat
}

if ($PSCmdlet.ShouldProcess("Bits service", "reset")) {
    sc.exe sdset bits "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
    sc.exe sdset wuauserv "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
}

foreach ($folder in $folders) {
    $location = Join-Path -Path $folder.Location -ChildPath $folder.Path
    $newname = "{0}-{1}" -f $folder.Path,$now_string

    Write-Verbose -Message "Renaming $location to $newname"
    Rename-Item -Path $location -NewName $newname
}

Push-Location $Env:windir
foreach ($svc in $extra_services) {
    if ($PSCmdlet.ShouldProcess("Service: $svc", "registering")) {
        if (Test-Path -Path $svc) {
            regsvr32.exe $svc
        } else {
            Write-Error -Message "Cannot find $svc"
        }
    }
}
Pop-Location

if ($PSCmdlet.ShouldProcess("Winsock", "reset")) {
    netsh winsock reset
    netsh winhttp reset proxy
}

foreach ($service in $services) {
    Write-Verbose -Message "Starting service: $service"
    if ($PSCmdlet.ShouldProcess("Service: $service", "Starting service")) {
        net start $service
        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message "Cannot start service: $service"
            # return
        }
    }
}

foreach ($folder in $folders) {
    $newname = "{0}-{1}" -f $folder.Path,$now_string
    $location = Join-Path -Path $folder.Location -ChildPath $newname

    Write-Verbose -Message "Deleting $location"
    if (Test-Path -Path $location -PathType Container) {
        Remove-Item -Path $location -Recurse -Force
    }
}

Write-Warning -Message "You need to reboot your machine now"
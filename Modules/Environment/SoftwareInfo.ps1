function Test-HasVisualStudio {
    $vs = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\VisualStudio\[0-9]* -ErrorAction SilentlyContinue
    -not ($null -eq $vs)
}

function Test-HasChocolatey {
    $choco = Get-Command -Name choco -ErrorAction SilentlyContinue
    -not ($null -eq $choco)
}

function Test-HasEmacs {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "Test-HasEmacs")]
    param()

    $emacs = Get-Command -Name emacsclient -ErrorAction SilentlyContinue
    -not ($null -eq $emacs)
}

function Test-IsIse {
    try
    {
        return $null -ne $psISE
    }
    catch
    {
        return $false
    }
}

function Test-HasNotepadPlusPlus {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "Test-HasNotepadPlusPlus")]
    param()

    return (Test-Path -Path 'C:\Program Files (x86)\Notepad++\notepad++.exe' -PathType Leaf)
}

function Get-NotepadPlusPlusPath {
    if (Test-HasNotepadPlusPlus) {
        'C:\Program Files (x86)\Notepad++\notepad++.exe'
    } else {
        Write-Error -Message "Notepad++ does not exist in this system"
        Throw "Notepad++ does not exist in this system"
    }
}

Function Get-WindowsProductKey
{

<#
.SYNOPSIS
Retrieves the Windows product key from the system.
Author: Jacob Soo (@jacobsoo)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None
.DESCRIPTION
Retrieves the Windows product key from the system.
.EXAMPLE
PS C:\>Get-Windows-ProductKey
Description
-----------
Retrieves the Windows product key from the system.
.NOTES
Code adapted from https://raw.githubusercontent.com/jacobsoo/PowerShellArsenal/master/Misc/Get-Windows-ProductKey.ps1
#>
    Param(
        [ValidateNotNullOrEmpty()]
        [string]$szComputer = $Env:COMPUTERNAME
    )

    $szRegistry = [WMIClass] ("\\" + $szComputer + "\root\default:StdRegProv")
    $values = [byte[]]($szRegistry.getbinaryvalue(2147483650,"SOFTWARE\Microsoft\Windows NT\CurrentVersion","DigitalProductId").uvalue)
    $lookup = [char[]]("B","C","D","F","G","H","J","K","M","P","Q","R","T","V","W","X","Y","2","3","4","6","7","8","9")
    $keyStartIndex = [int]52;
    $keyEndIndex = [int]($keyStartIndex + 15);
    $iDecodedLength = [int]29
    $decodeStringLength = [int]15
    $szDecodedChars = new-object char[] $iDecodedLength
    $hexPid = new-object System.Collections.ArrayList
    for ($i = $keyStartIndex; $i -le $keyEndIndex; $i++){
        [void]$hexPid.Add($values[$i])
    }
    for ( $i = $iDecodedLength - 1; $i -ge 0; $i--){
        if (($i + 1) % 6 -eq 0){
            $szDecodedChars[$i] = '-'
        }else{
            $digitMapIndex = [int]0
            for ($j = $decodeStringLength - 1; $j -ge 0; $j--){
                $byteValue = [int](($digitMapIndex * [int]256) -bor [byte]$hexPid[$j]);
                $hexPid[$j] = [byte] ([math]::Floor($byteValue / 24));
                $digitMapIndex = $byteValue % 24;
                $szDecodedChars[$i] = $lookup[$digitMapIndex];
            }
        }
    }
    $szProductKey = ''
    $szDecodedChars | ForEach-Object { $szProductKey += $_}
    $szProductKey
}

<#
.SYNOPSIS
Outputs installed applications for one or more computers.

.DESCRIPTION
Outputs installed applications for one or more computers.

(64-bit Windows only) If you run Get-InstalledApp.ps1 in 32-bit PowerShell on a 64-bit version of Windows, Get-InstalledApp.ps1 can only detect 32-bit applications.

.PARAMETER ComputerName
Outputs applications for the named computer(s). If you omit this parameter, the local computer is assumed.

.PARAMETER AppID
Outputs applications with the specified application ID. An application's appID is equivalent to its subkey name underneath the Uninstall registry key. For Windows Installer-based applications, this is the application's product code GUID (e.g. {3248F0A8-6813-11D6-A77B-00B0D0160060}). Wildcards are permitted.

.PARAMETER AppName
Outputs applications with the specified application name. The AppName is the application's name as it appears in the Add/Remove Programs list. Wildcards are permitted.

.PARAMETER Publisher
Outputs applications with the specified publisher name. Wildcards are permitted

.PARAMETER Version
Outputs applications with the specified version. Wildcards are permitted.

.PARAMETER Architecture
Outputs applications for the specified architecture. Valid arguments are: 64-bit and 32-bit. Omit this parameter to output both 32-bit and 64-bit applications. Note that 32-bit PowerShell on 64-bit Windows does not output 64-bit applications.

.PARAMETER MatchAll
Outputs all matching applications. Otherwise, output only the first match.

.INPUTS
System.String

.OUTPUTS
PSObjects containing the following properties:
  ComputerName - computer where the application is installed
  AppID - the application's AppID
  AppName - the application's name
  Publisher - the application's publisher
  Version - the application's version
  Architecture - the application's architecture (32-bit or 64-bit)

.EXAMPLE
PS C:\> Get-InstalledApplications
This command outputs installed applications on the current computer.

.EXAMPLE
PS C:\> Get-InstalledApplications | Select-Object AppName,Version | Sort-Object AppName
This command outputs a sorted list of applications on the current computer.

.EXAMPLE
PS C:\> Get-InstalledApplications wks1,wks2 -Publisher *microsoft* -MatchAll
This command outputs all installed Microsoft applications on the named computers.

.EXAMPLE
PS C:\> Get-Content ComputerList.txt | Get-InstalledApplications -AppID "{1A97CF67-FEBB-436E-BD64-431FFEF72EB8}" | Select-Object ComputerName
This command outputs the computer names named in ComputerList.txt that have the specified application installed.

.EXAMPLE
PS C:\> Get-InstalledApplications -Architecture "32-bit" -MatchAll
This command outputs all 32-bit applications installed on the current computer.

.NOTES
Written by Bill Stewart (bstewart@iname.com).
Adapted from http://windowsitpro.com/scripting/auditing-32-bit-and-64-bit-applications-powershell
#>
function Get-InstalledApplications {
    [CmdletBinding()]
    param(
    [parameter(Position=0,ValueFromPipeline=$TRUE)]
        [String[]] $ComputerName=$ENV:COMPUTERNAME,
        [String] $AppID,
        [String] $AppName,
        [String] $Publisher,
        [String] $Version,
        [String] [ValidateSet("32-bit","64-bit")] $Architecture,
        [Switch] $MatchAll
    )

    begin {
    $HKLM = [UInt32] "0x80000002"
    $UNINSTALL_KEY = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $UNINSTALL_KEY_WOW = "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

    # Detect whether we are using pipeline input.
    $PIPELINEINPUT = (-not $PSBOUNDPARAMETERS.ContainsKey("ComputerName")) -and (-not $ComputerName)

    # Create a hash table containing the requested application properties.
    $PropertyList = @{}
    if ($AppID -ne "") { $PropertyList.AppID = $AppID }
    if ($AppName -ne "") { $PropertyList.AppName = $AppName }
    if ($Publisher -ne "") { $PropertyList.Publisher = $Publisher }
    if ($Version -ne "") { $PropertyList.Version = $Version }
    if ($Architecture -ne "") { $PropertyList.Architecture = $Architecture }

    # Returns $TRUE if the leaf items from both lists are equal; $FALSE otherwise.
    function compare-leafequality($list1, $list2) {
        # Create ArrayLists to hold the leaf items and build both lists.
        $leafList1 = new-object System.Collections.ArrayList
        $list1 | foreach-object { [Void] $leafList1.Add((split-path $_ -leaf)) }
        $leafList2 = new-object System.Collections.ArrayList
        $list2 | foreach-object { [Void] $leafList2.Add((split-path $_ -leaf)) }
        # If compare-object has no output, then the lists matched.
        (compare-object $leafList1 $leafList2 | measure-object).Count -eq 0
    }

    function get-installedapp2($computerName) {
        try {
        $regProv = [WMIClass] "\\$computerName\root\default:StdRegProv"

        # Enumerate HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
        # Note that this request will be redirected to Wow6432Node if running from 32-bit
        # PowerShell on 64-bit Windows.
        $keyList = new-object System.Collections.ArrayList
        $keys = $regProv.EnumKey($HKLM, $UNINSTALL_KEY)
        foreach ($key in $keys.sNames) {
            [Void] $keyList.Add((join-path $UNINSTALL_KEY $key))
        }

        # Enumerate HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall
        $keyListWOW64 = new-object System.Collections.ArrayList
        $keys = $regProv.EnumKey($HKLM, $UNINSTALL_KEY_WOW)
        if ($keys.ReturnValue -eq 0) {
            foreach ($key in $keys.sNames) {
            [Void] $keyListWOW64.Add((join-path $UNINSTALL_KEY_WOW $key))
            }
        }

        # Default to 32-bit. If there are any items in $keyListWOW64, then compare the
        # leaf items in both lists of subkeys. If the leaf items in both lists match, we're
        # seeing the Wow6432Node redirection in effect and we can ignore $keyListWOW64.
        # Otherwise, we're 64-bit and append $keyListWOW64 to $keyList to enumerate both.
        $is64bit = $FALSE
        if ($keyListWOW64.Count -gt 0) {
            if (-not (compare-leafequality $keyList $keyListWOW64)) {
            $is64bit = $TRUE
            [Void] $keyList.AddRange($keyListWOW64)
            }
        }

        # Enumerate the subkeys.
        foreach ($subkey in $keyList) {
            $name = $regProv.GetStringValue($HKLM, $subkey, "DisplayName").sValue
            if ($name -eq $NULL) { continue }  # skip entry if empty display name
            $output = new-object PSObject
            $output | add-member NoteProperty "ComputerName" -value $computerName
            # $output | add-member NoteProperty "Subkey" -value (split-path $subkey -parent)  # useful when debugging
            $output | add-member NoteProperty "AppID" -value (split-path $subkey -leaf)
            $output | add-member NoteProperty "AppName" -value $name
            $output | add-member NoteProperty "Publisher" -value $regProv.GetStringValue($HKLM, $subkey, "Publisher").sValue
            $output | add-member NoteProperty "Version" -value $regProv.GetStringValue($HKLM, $subkey, "DisplayVersion").sValue

            $installDate = $regProv.GetStringValue($HKLM, $subkey, "InstallDate").sValue
            try {
                $parsedInstallDate = [System.DateTime]::ParseExact($installDate, "yyyyMMdd", [System.Globalization.CultureInfo]::InvariantCulture)
                $output | add-member NoteProperty "InstallDate" -value $parsedInstallDate
            } catch [System.FormatException] {
                Write-Warning -Message "Cannot get install time for $name (value: $installDate)"
            }


            # If subkey's name is in Wow6432Node, then the application is 32-bit. Otherwise,
            # $is64bit determines whether the application is 32-bit or 64-bit.
            if ($subkey -like "SOFTWARE\Wow6432Node\*") {
            $appArchitecture = "32-bit"
            } else {
            if ($is64bit) {
                $appArchitecture = "64-bit"
            } else {
                $appArchitecture = "32-bit"
            }
            }
            $output | add-member NoteProperty "Architecture" -value $appArchitecture

            # If no properties defined on command line, output the object.
            if ($PropertyList.Keys.Count -eq 0) {
            $output
            } else {
            # Otherwise, iterate the requested properties and count the number of matches.
            $matches = 0
            foreach ($key in $PropertyList.Keys) {
                if ($output.$key -like $PropertyList.$key) {
                $matches += 1
                }
            }
            # If all properties matched, output the object.
            if ($matches -eq $PropertyList.Keys.Count) {
                $output
                # If -matchall is missing, don't enumerate further.
                if (-not $MatchAll) { break }
            }
            }
        }
        }
        catch [System.Management.Automation.RuntimeException] {
        write-error $_
        }
    }
    }

    process {
    if ($PIPELINEINPUT) {
        get-installedapp2 $_
    } else {
        $ComputerName | foreach-object {
        get-installedapp2 $_
        }
    }
    }
}
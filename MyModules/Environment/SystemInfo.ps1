function Get-OsInfo {
	param(
	    [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Connection -ComputerName $_ -Count 1 -Quiet})]
		[string[]]
		$ComputerName = "localhost"
	)

    BEGIN {}
    PROCESS {
        foreach ($computer in $ComputerName) {
	        Get-CimInstance -ClassName CIM_OperatingSystem -ComputerName $computer
        }
    }
    END {}
}

function Get-HwInfo {
    param(
	    [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Connection -ComputerName $_ -Count 1 -Quiet})]
		[string[]]
		$ComputerName = "localhost"
	)

    BEGIN {}
    PROCESS {
        foreach ($computer in $ComputerName) {
	        Get-CimInstance -ClassName CIM_ComputerSystem -ComputerName $computer
        }
    }
    END {}
}

function Get-PathFromRegistry {
        $Reg = "Registry::HKLM\System\CurrentControlSet\Control\Session Manager\Environment"
        (Get-ItemProperty -Path "$Reg" -Name PATH).Path
}

function Get-Bootup
{
<#
.SYNOPSIS
Get the System's bootup time and convert it to UTC time.
Author: Jacob Soo (@jacobsoo)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None
.DESCRIPTION
Get the System's bootup time and convert it to UTC time.
.EXAMPLE
PS C:\>Get-Bootup
Description
-----------
Get the System's bootup time and convert it to UTC time.
.NOTES
Code adapted from https://raw.githubusercontent.com/jacobsoo/PowerShellArsenal/master/Forensics/Get-Bootup-UTCTime.ps1
#>
    [OutputType([System.DateTime])]
    [CmdletBinding()]
    param(
        [ValidateSet("UTC", "Local")]
        [string]$Timezone = "UTC"
    )

    $szBootupTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

    switch($Timezone){
        'UTC'   { $bootTime = [System.TimeZoneInfo]::ConvertTimeToUtc($szBootupTime) }
        'Local' { $bootTime = $szBootupTime  }
        default { $bootTime = [System.TimeZoneInfo]::ConvertTimeToUtc($szBootupTime)}
    }

    Write-Output $bootTime
}
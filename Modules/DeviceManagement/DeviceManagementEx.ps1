function Get-DeviceErrorCodeDescription {
    [CmdletBinding()]
    param(
        [System.UInt32]$Code
    )

    # Descriptions from https://support.microsoft.com/en-us/help/310123/error-codes-in-device-manager-in-windows
    switch ($Code) {
         0 { "Device Ok" }
         1 { "The device has no drivers installed on your computer, or the drivers are configured incorrectly." }
         3 { "The driver for this device might be corrupted, or your system may be running low on memory or other resources." }
         9 { "Windows cannot identifythis hardware because it does not have a valid hardware identification number. For assistance, contact the hardware manufacturer." }
        10 { "This device cannot start. Try upgrading the device drivers for this device." }
        12 { "This device cannot find enough free resources that it can use. If you want to use this device, you will need to disable one of the other devices on this system." }
        14 { "This device cannot work properly until you restart your computer. To restart your computer now, click Restart Computer." }
        16 { "Windows cannot identify all the resources this device uses. To specify additional resources for this device, click the Resources tab and fill in the missing settings. Check your hardware documentation to find out what settings to use." }
        18 { "Reinstall the drivers for this device." }
        19 { "Windows cannot start this hardware device because its configuration information (in the registry) is incomplete or damaged." }
        21 { "Windows is removing this device." }
        22 { "The device was disabled by the user in Device Manager." }
        24 { "This device is not present, is not working properly, or does not have all its drivers installed." }
        28 { "The drivers for this device are not installed." }
        29 { "This device is disabled because the firmware of the device did not give it the required resources." }
        31 { "This device is not working properly because Windows cannot load the drivers required for this device." }
        32 { "A driver (service) for this device has been disabled. An alternate driver may be providing this functionality." }
        33 { "The translator that determines the kinds of resources that are required by the device has failed." }
        34 { "Windows cannot determine the settings for this device. Consult the documentation that came with this device and use the Resource tab to set the configuration." }
        35 { "Your computer's system firmware does not include enough information to properly configure and use this device. To use this device, contact your computer manufacturer to obtain a firmware or BIOS update." }
        36 { "This device is requesting a PCI interrupt but is configured for an ISA interrupt (or vice versa). Please use the computer's system setup program to reconfigure the interrupt for this device."}
        37 { "The driver returned a failure when it executed the DriverEntry routine."}
        38 { "Windows cannot load the device driver for this hardware because a previous instance of the device driver is still in memory." }
        39 { "Windows cannot load the device driver for this hardware. The driver may be corrupted or missing." }
        40 { "Windows cannot access this hardware because its service key information in the registry is missing or recorded incorrectly." }
        41 { "Windows successfully loaded the device driver for this hardware but cannot find the hardware device." }
        42 { "Windows cannot load the device driver for this hardware because there is a duplicate device already running in the system." }
        43 { "One of the drivers controlling the device notified the operating system that the device failed in some manner." }
        44 { "An application or service has shut down this hardware device."}
        45 { "Currently, this hardware deviceis not connected to the computer. To fix this problem, reconnect this hardware device to the computer." }
        46 { "Windows cannot gain access to this hardware device because the operating system is in the processof shutting down. The hardware device should work correctly next time you start your computer." }
        47 { "Windows cannot use this hardware device because it has been prepared for safe removal, but it has not been removed from the computer. To fix this problem, unplug this device from your computer and then plug it in again." }
        48 { "The software for this device has been blocked from starting because it is known to have problems with Windows. Contact the hardware vendor for a new driver" }
        49 { "Windows cannot start new hardware devices because the system hive is too large" }
        50 { "Windows cannot apply all of the properties for this device. Device properties may include information that describes the device's capabilities and settings (such as security settings for example). To fix this problem, you can try reinstalling this device. However,we recommend that you contact the hardware manufacturer for a new driver." }
        51 { "This device is currently waiting on another device or set of devices to start." }
        52 { "Windows cannot verify the digital signature for the drivers required for this device. A recent hardware or software change might have installed a file that is signed incorrectly or damaged, or that might be malicious software from an unknown source." }
        53 { "This device has been reserved for use by the Windows kernel debugger for the duration of this boot session." }
        54 { "This is an intermittent problem code assigned while an ACPI reset method is being executed. If the device never restarts due to a failure, it will be stuck in this state and the system should be rebooted." }
        Default { "Unknown error code: $Code"}
    }
}

function Get-DeviceEx {
    [CmdletBinding()]
    param (
        [switch]$Faulty,
        [switch]$Short
    )

    $devices = Get-WmiObject -Class Win32_PNPEntity
    if ($Faulty) {
        $devices = $devices | Where-Object -Property ConfigManagerErrorcode -NE -Value 0
    }

    $devices = $devices | `
                ForEach-Object -Process {
                    $_ | Add-Member -MemberType NoteProperty -Name "ErrorCodeDescription" -Value (Get-DeviceErrorCodeDescription -Code $_.ConfigManagerErrorcode) -Force -PassThru
                }

    if ($Short) {
        $devices = $devices | Select-Object -Property Name,Description,ErrorCodeDescription
    }

    return $devices
}

function Get-DeviceCom {
    [CmdletBinding()]
    param(
        [string]
        $ComputerName = $null
    )

    if (($ComputerName -eq $null) -or ($ComputerName -eq "localhost") -or ($ComputerName -eq "")) {
        $remote = $false
    } else {
        $remote = $true
    }
    Write-Debug -Message "Running on remote computer: $remote ($ComputerName)"

    # To identify the COM devices we follow the steps below:
    # 1. Use "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\COM Name Arbiter\Devices" to identify *active* devices
    # 2. Search the device under "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum"

    # TODO: There is duplication of code below. We want to merge.

    if ($remote) {
        Write-Verbose -Message "Retrieving list of COM ports on remote device"
        [PSCustomObject[]]$normalized = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $devices = Get-Item -Path "HKLM:SYSTEM\CurrentControlSet\Control\COM Name Arbiter\Devices" -ErrorAction SilentlyContinue

            if ($devices -eq $null) {
                Write-Verbose -Message "No COM devices seems to be active on $ComputerName"
                return
            } else {
                Write-Verbose -Message "Found devices on remote machine"
            }

            $normalized = $devices.Property | ForEach-Object -Process {
                $port = $_
                $name = $devices.GetValue($port)
                $ids  = $name.Split('#')

                if ($ids.Length -le 2) {
                    Write-Error -Message "Unexpected number of elements in path $_"
                    continue
                }

                $prefix = $ids[0]
                if (($prefix.StartsWith("\\?\") -eq $false) -or ($prefix.Length -le 4)) {
                    Write-Error -Message "Unexpected prefix: $prefix"
                    continue
                } else {
                    $prefix = $prefix.Substring(4)
                }

                $inside = $ids[1..($ids.Length-2)]
                $proper = [System.IO.Path]::Combine($prefix, [System.String]::Join([System.IO.Path]::DirectorySeparatorChar, $inside))

                $registryPath = [System.IO.Path]::Combine("HKLM:SYSTEM\CurrentControlSet\Enum", $proper)

                if ($remote) {
                    $registry = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                        Get-Item -Path $registryPath
                    }
                } else {
                    $registry = Get-Item -Path $registryPath
                }

                [PSCustomObject]@{
                    Port = $port
                    FriendlyName = $registry.GetValue("FriendlyName")
                    Name = $name
                    Prefix = $proper
                    Registry = $registry
                }
            }

            return ($normalized)
        }

        if ($normalized -ne $null) {
            Write-Verbose -Message "Found $($normalized.Length) devices on remote $ComputerName"
        } else {
            Write-Verbose -Message "Did not found any devices on remote machine"
        }
    } else {
        $devices = Get-Item -Path "HKLM:SYSTEM\CurrentControlSet\Control\COM Name Arbiter\Devices" -ErrorAction SilentlyContinue

        if ($devices -eq $null) {
            Write-Verbose -Message "No COM devices seems to be active"
        }

        $normalized = $devices.Property | ForEach-Object -Process {
            $port = $_
            $name = $devices.GetValue($port)
            $ids  = $name.Split('#')

            if ($ids.Length -le 2) {
                Write-Error -Message "Unexpected number of elements in path $_"
                continue
            }

            $prefix = $ids[0]
            if (($prefix.StartsWith("\\?\") -eq $false) -or ($prefix.Length -le 4)) {
                Write-Error -Message "Unexpected prefix: $prefix"
                continue
            } else {
                $prefix = $prefix.Substring(4)
            }

            $inside = $ids[1..($ids.Length-2)]
            $proper = [System.IO.Path]::Combine($prefix, [System.String]::Join([System.IO.Path]::DirectorySeparatorChar, $inside))

            $registryPath = [System.IO.Path]::Combine("HKLM:SYSTEM\CurrentControlSet\Enum", $proper)

            if ($remote) {
                $registry = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                    Get-Item -Path $registryPath
                }
            } else {
                $registry = Get-Item -Path $registryPath
            }

            [PSCustomObject]@{
                Port = $port
                FriendlyName = $registry.GetValue("FriendlyName")
                Name = $name
                Prefix = $proper
                Registry = $registry
            }
        }

        if ($normalized -ne $null) {
            Write-Verbose -Message "Found $($normalized.Length) devices on local machine"
        }
    }

    if ($normalized -eq $null) { return }

    $normalized | Add-Member -TypeName "DeviceComInformation"
    Update-TypeData -DefaultDisplayPropertySet Port,FriendlyName -Force -TypeName "DeviceComInformation"
    return $normalized
}
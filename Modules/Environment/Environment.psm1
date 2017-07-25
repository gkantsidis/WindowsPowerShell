﻿#
# Include all files that compose the module
#

$RootOfPowershellDirectory = $PSScriptRoot

. $PSScriptRoot/Modules.ps1
. $PSScriptRoot/MsiHelper.ps1
. $PSScriptRoot/Filesystem.ps1
. $PSScriptRoot/DateTime.ps1          # Works ok in Unix
. $PSScriptRoot/Scoop.ps1
. $PSScriptRoot/Settings.ps1
. $PSScriptRoot/SoftwareInfo.ps1      # Works ok in Unix; does not do anything interesting though
. $PSScriptRoot/SystemInfo.ps1        # This requires Windows
. $PSScriptRoot/TextFile.ps1
. $PSScriptRoot/Windowing.ps1         # This requires Windows
. $PSScriptRoot/Debuggers.ps1
. $PSScriptRoot/Calendar.ps1
. $PSScriptRoot/Get-PendingReboot.ps1 # This requires Windows
. $PSScriptRoot/Security.ps1
#Requires -Modules xUtility

[CmdletBinding(SupportsShouldProcess=$true)]
param()

# Stores all paths examined so far
$exist = New-Object -TypeName 'System.Collections.Generic.HashSet[string]'

[string]$systemPaths = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
[string]$userPaths = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
$sizeOfSystemPath = $systemPaths.Length
$sizeOfUserPath = $userPaths.Length

# TODO: Make a copy of those paths in local files

# Process machine paths
[string[]]$paths = @()
if (-not [string]::IsNullOrWhiteSpace($systemPaths)) {
    [string[]]$systemPaths = $systemPaths.Split(';')
} else {
    [string[]]$systemPaths = @()
}

$dirty = $false
foreach($path in $systemPaths) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        $dirty = $true
        continue
    }
    if ($exist.Contains($path)) {
        Write-Verbose -Message "Duplicate detected: $path"
        $dirty = $true
        continue
    }
    $exist.Add($path) | Out-Null

    if (-not (Test-Path -Path $path)) {
        Write-Verbose -Message "Directory does not exist: $path"
        $dirty = $true
        continue
    }

    $paths += $path
}
[string]$systemPath = [string]::Join(';', $paths)
if ($dirty -and (-not $WhatIfPreference) -and (Test-AdminRights)) {
    Write-Verbose -Message "Changing system path"
    [System.Environment]::SetEnvironmentVariable("Path", $systemPath, [System.EnvironmentVariableTarget]::Machine)
} elseif ($dirty) {
    Write-Host "System path should be: $systemPath"
}
if ($dirty) {
    Write-Verbose -Message ("System path size reduction: {0} -> {1}" -f $sizeOfSystemPath,$systemPath.Length)
}

#
# Process user paths
#
# TODO: Same code as above, need to refactor

[string[]]$paths = @()
if (-not [string]::IsNullOrWhiteSpace($userPaths)) {
    [string[]]$userPaths = $userPaths.Split(';')
} else {
    [string[]]$userPaths = @()
}

$dirty = $false
foreach($path in $userPaths) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        $dirty = $true
        continue
    }
    if ($exist.Contains($path)) {
        Write-Verbose -Message "Duplicate detected: $path"
        $dirty = $true
        continue
    }
    $exist.Add($path) | Out-Null

    if (-not (Test-Path -Path $path)) {
        Write-Verbose -Message "Directory does not exist: $path"
        $dirty = $true
        continue
    }

    $paths += $path
}
[string]$userPaths = [string]::Join(';', $paths)
if ($dirty -and (-not $WhatIfPreference)) {
    Write-Verbose -Message "Changing user path to: $userPaths"
    [System.Environment]::SetEnvironmentVariable("Path", $userPaths, [System.EnvironmentVariableTarget]::User)
} elseif ($dirty) {
    Write-Host "User path should be: $userPaths"
}
if ($dirty) {
    Write-Verbose -Message ("User path size reduction: {0} -> {1}" -f $sizeOfUserPath,$userPaths.Length)
}

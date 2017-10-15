#Requires -RunAsAdministrator
#Requires -Module PowerShellGet

<#PSScriptInfo

.VERSION 2.0

.GUID ad9d9052-dd2e-42ef-8b4d-4119a3e62cbd

.AUTHOR Christos Gkantsidis

.COMPANYNAME

.COPYRIGHT

.TAGS

.LICENSEURI
https://raw.githubusercontent.com/gkantsidis/WindowsPowerShell/master/LICENSE

.PROJECTURI
https://github.com/gkantsidis/WindowsPowerShell

.ICONURI

.EXTERNALMODULEDEPENDENCIES
PowerShellGet

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


#>

function UninstallModule {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [string]
        $Name,

        $Version
    )

    Write-Debug -Message "Uninstalling $name of $Version"
    Uninstall-Module -Name $name -RequiredVersion $Version -ErrorAction SilentlyContinue
    $oldversion = Get-Module $Name -ListAvailable | Where-Object -Property Version -EQ -Value $Version
    if ($oldversion) {
        $path = Split-Path -Path $oldversion.Path -Parent
        Write-Verbose -Message "Failed to uninstall module $name as a package; will try to remove directory $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -Path $path) {
            Write-Error -Message "Failed to uninstall module $name by removing directory $path; please uninstall manually"
        }
    }
}

function Remove-OldModules {
    <#
    .SYNOPSIS
    Cleanups the installed modules

    .DESCRIPTION
    Checks the installed modules and removes old versions.

    .EXAMPLE
    PS> Remove-OldModules

    .NOTES
    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    Param()

    $modules = Get-Module -ListAvailable | Sort-Object -Property Name,Version -Descending
    # Assumption: the modules are grouped by name, and the newest version comes first.

    $modules | ForEach-Object -Begin {
        $prevName = $null
        $newestVersion = $null
        # $prevType = $null
    } -Process {
        $name = $_.Name
        $version = $_.Version
        $type = $_.ModuleType

        Write-Debug -Message "Found $name with version $version of type $type"

        if (($null -eq $prevName) -or ($name -ne $prevName)) {
            # Do nothing; pick up the new info and continue below
            $prevName = $name
            $prevType = $type
            $newestVersion = $version
    #    } elseif ($prevType -ne $type) {
    #        Write-Verbose "Detected different types for module $name; previous is $prevType with $newestVersion; current is $type with $version"
        } elseif ($newestVersion -lt $version) {
            Write-Verbose "Detected old version of module $name : old=$newestVersion, current=$version; Removing $newestVersion ..."
            UninstallModule -Name $name -Version $newestVersion
            $newestVersion = $version
        } elseif ($version -lt $newestVersion) {
            Write-Verbose "Detected old version of module $name : old=$version, current=$newestVersion; Removing $version ..."
            UninstallModule -Name $name -Version $version
        } else {
            Write-Error -Message "The module $name appears to have two installations for the same version $version"
        }
    }
}

function Update-Modules {
    <#
    .SYNOPSIS
    Updates all modules to their newest version.

    .DESCRIPTION
    Checks all modules installed with PowerShellGet or equivalent and installs
    their newest versions from the server.

    .PARAMETER Concurrent
    Number of concurrent modules to check from server.

    .PARAMETER AllModules
    Examine all modules

    .EXAMPLE
    PS> Update-Modules

    .NOTES
    TODO: Local modules can have multiple versions.
    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [int]$Concurrent = 50,

        [switch]$AllModules
    )

    if ($AllModules) {
        $modules = Get-Module -ListAvailable -All
    } else {
        $modules = Get-InstalledModule
    }

    $names = $modules | Select-Object -ExpandProperty Name | Sort-Object -Unique

    [string[]]$update = @()

    for ($i = 0; $i -lt $names.Count; $i += $Concurrent) {
        $end = $i + $Concurrent - 1
        if ($end -ge $names.Count) {
            $end = $names.Count - 1
        }
        $examine = $names[$i..$end]
        Write-Debug -Message "Examining modules $($examine[0]) ($i) to $($examine[-1]) ($end)"

        $server = Find-Module -Name $examine

        [string[]]$to_update = $examine | ForEach-Object -Process {
            $module = $_
            $installed = @(, ($modules | Where-Object -Property Name -EQ -Value $module))
            $current =  @(, ($server | Where-Object -Property Name -EQ -Value $module))

            if ($installed.Count -ne 1) {
                Write-Error -Message "Expected exactly one item in installed --- need to handle multiple versions"
                continue
            }
            if ($current.Count -ne 1) {
                Write-Error -Message "Expected exactly one item in current"
                continue
            }

            $installed = $installed[0]
            $current = $current[0]

            Write-Debug -Message "Module: $module`t Installed: $($installed.Version), Current: $($current.Version)"

            $comparison = $installed.Version.CompareTo($current.Version)
            if ($comparison -eq 1) {
                Write-Warning -Message "Module $module has more recent local version (Installed: $($installed.Version), Current: $($current.Version))"
            } elseif ($comparison -eq 0) {
                Write-Debug -Message "Module $module is up to date"
            } else {
                Write-Verbose -Message "Module $module needs updating (Installed: $($installed.Version), Current: $($current.Version))"
                $module
            }
        }

        if (($to_update -ne $null) -and ($to_update.Count -gt 0)) {
            $update += $to_update
        }
    }

    Write-Verbose -Message "Need to update $($update.Count) modules: $update"

    for ($i = 0; $i -lt $update.Count; $i += $Concurrent) {
        $end = $i + $Concurrent - 1
        if ($end -ge $update.Count) {
            $end = $update.Count - 1
        }
        $need_update = $update[$i..$end]

        Update-Module -Name $need_update -Force
    }
}

Export-ModuleMember -Function Remove-OldModules,Update-Modules
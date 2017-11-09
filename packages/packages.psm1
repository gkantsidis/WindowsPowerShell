#Requires -Module Pipeworks

$Configuration = (Join-Path -Path $PSScriptRoot -ChildPath "packages.json")
$config = Get-Content -Path $Configuration | ConvertFrom-Json
$packages = $PSScriptRoot

$registered = $false

function DownloadModule($module) {
    $name = $module.Name
    Write-Debug -Message "Downloading $name"
    $get = $module.Download
    $method = $get.Method.ToUpperInvariant()
    switch ($method) {
        "Web" {
            $url = $get.URL
            Write-Warning -Message "Please be patient: downloading and installing $name from $url"

            $filename = [System.IO.FileInfo]::new([System.IO.Path]::GetTempFileName())
            $filename = Join-Path -Path $filename.DirectoryName -ChildPath ($filename.BaseName + ".zip")
            Try {
                Invoke-WebRequest -Uri $url -OutFile $filename
                Expand-Zip -ZipPath $filename -OutputPath $script:packages
            }
            Finally {
                if (Test-Path -Path $filename) {
                    Remove-Item -Path $filename -Force
                }
            }
        }

        default {
            Write-Warning -Message "Do not implement method $($get.Method)"
            return
        }
    }
}

function LoadModule($module) {
    $name = $module.Name
    Write-Debug -Message "Loading local module $name"

    $directory = Join-Path -Path $script:packages -ChildPath $module.Directory
    if (-not (Test-Path -Path $directory -PathType Container)) {
        # Directory does not exist; will need to download
        DownloadModule($module)

        if (-not (Test-Path -Path $directory -PathType Container)) {
            Write-Warning -Message "Could not download $name"
            return
        }
    } else {
        Write-Debug -Message "Package $name is available locally"
    }

    [string[]]$binary = $module.Binary | Where-Object {
        ($_.Edition -eq $PSEdition) -and ($_.Platform -eq [Environment]::OSVersion.Platform)
    } | Select-Object -ExpandProperty "File"

    if (($binary -eq $null) -or (($binary.Length -eq 1) -and [string]::IsNullOrWhiteSpace($binary[0]))) {
        Write-Warning -Message "Package is not available for this architecture/configuration"
        return
    } elseif ($binary.Length -gt 1) {
        Write-Warning -Message "Multiple target binaries found for this configuration"
        return
    }

    # There is exactly one value for this entry
    $dll = $binary[0]
    if ($dll -isnot [string]) {
        Write-Warning -Message "Internal error: expecting string here, got $($dll.GetType())"
        return
    }
    if ([string]::IsNullOrWhiteSpace($dll)) {
        Write-Warning -Message "Internal error: cannot find path for $name"
        return
    }
    Write-Debug -Message "Will try loading $dll : $($dll.GetType())"
    $dllpath = Join-Path -Path $directory -ChildPath $dll
    if (-not (Test-Path -Path $dllpath -PathType Leaf)) {
        Write-Warning -Message "Target binary does not exist in: $dllpath"
        return
    }

    $target = Get-Item -Path $dllpath
    Push-Location -Path $target.DirectoryName
    Try {
        $n = ".\{0}" -f $target.Name
        Write-Debug -Message "Importing $n from $($target.DirectoryName)"
        Import-Module $n
    }
    Finally {
        Pop-Location
    }
}

$OnAssemblyResolve = [System.ResolveEventHandler] {
    param($sender, $e)

    $index = $e.Name.IndexOf(",")
    if ($index -gt 0) {
        $name = $e.Name.Substring(0, $index)
    } else {
        $name = $e
    }

    Write-Debug -Message "Looking for $name : $($e.Name)"
    [PSCustomObject[]]$module=$config.Modules | Where-Object -FilterScript {
        $_.DynamicLoading -and [string]::Equals($_.Name, $name, [System.StringComparison]::InvariantCultureIgnoreCase)
    }
    if ($module -eq $null) {
        Write-Debug -Message "Module $name not handled by us"
        return $null
    }

    if (-not (Get-Module -Name $name)) {
        # Module is not loaded

        if ((Import-Module -Name log4net -ErrorAction SilentlyContinue) -eq $null) {
            # ... and it does not exist
            if ($module -is [array]) {
                if ($module.Length -gt 1) {
                    Write-Error -Message "Multiple entries for $name detected"
                } else {
                    LoadModule($module[0])
                }
            } else {
                # Module is not handled here
                return $null
            }
        } else {
            Write-Debug -Message "Module $name seems to exist, but it is not loaded"
        }
    } else {
        Write-Debug -Message "Module $name appears to be already loaded"
    }

    $assemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()

    # First attempt: look for exact match
    foreach($a in $assemblies)
    {
      if ($a.FullName -eq $e.Name)
      {
        Write-Debug -Mesage "... Found $($a.FullName)"
        return $a
      }
    }

    # Second attempt: look for same name
    foreach($a in $assemblies)
    {
      Write-Debug -Message "Testing $($a.GetName().Name) with $($e.Name) : $($e.Name.GetType())"
      if ($a.GetName().Name -eq $name)
      {
        Write-Verbose -Message "... Found $($a.FullName)"
        return $a
      }
    }

    return $null
}

function Register-ExtraPackages {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [string]$Configuration = (Join-Path -Path $PSScriptRoot -ChildPath "packages.json"),

        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path -Path $_ -PathType Container})]
        [string]$PackageDirectory = $PSScriptRoot
    )

    Write-Debug -Message "Config file: $Configuration"
    Write-Debug -Message "Package directory: $PackageDirectory"
    $script:config = Get-Content -Path $Configuration | ConvertFrom-Json
    $script:packages = $PackageDirectory

    if (-not $registered) {
        Write-Debug -Message "Registering handler"
        [System.AppDomain]::CurrentDomain.add_AssemblyResolve($script:OnAssemblyResolve)
        $script:registered = $true
    } else {
        Write-Debug -Message "Handler is already registered"
    }

# if (-not (Test-Path -Path "log4net-1.2.15" -PathType Container)) {
#     $filename = [System.IO.FileInfo]::new([System.IO.Path]::GetTempFileName())
#     $filename = Join-Path -Path $filename.DirectoryName -ChildPath ($filename.BaseName + ".zip")
#     Try {
#         Invoke-WebRequest `
#             -Uri "http://archive.apache.org/dist/logging/log4net/binaries/log4net-1.2.15-bin-newkey.zip" `
#             -OutFile $filename
#         Expand-Zip -ZipPath $filename -OutputPath $PackageDirectory
#     }
#     Finally {
#         if (Test-Path -Path $filename) {
#             Remove-Item -Path $filename -Force
#         }
#     }
# }

# $OnAssemblyResolve = [System.ResolveEventHandler] {
#     param($sender, $e)

#     $index = $e.Name.IndexOf(",")
#     if ($index -gt 0) {
#         $name = $e.Name.Substring(0, $index)
#     } else {
#         $name = $e
#     }

#     Write-Debug -Message "Looking for $name : $($e.Name)"

#     $assemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()

#     # First attempt: look for exact match
#     foreach($a in $assemblies)
#     {
#       if ($a.FullName -eq $e.Name)
#       {
#         Write-Debug -Mesage "... Found $($a.FullName)"
#         return $a
#       }
#     }

#     # Second attempt: look for same name
#     foreach($a in $assemblies)
#     {
#       Write-Debug -Message "Testing $($a.GetName().Name) with $($e.Name) : $($e.Name.GetType())"
#       if ($a.GetName().Name -eq $name)
#       {
#         Write-Verbose -Message "... Found $($a.FullName)"
#         return $a
#       }
#     }

#     return $null
#   }

# if (-not (Test-Path Env:CUSTOM_ASSEMBLY_RESOLVE_INITIALIZED)) {
#     [System.AppDomain]::CurrentDomain.add_AssemblyResolve($OnAssemblyResolve)
#     $Env:CUSTOM_ASSEMBLY_RESOLVE_INITIALIZED = "TRUE"
# } else {
#     Write-Verbose -Message "Handler already registered"
# }

# if (-not (Get-Module log4net)) {
#     Push-Location -Path "$PSScriptRoot\log4net-1.2.15\bin\net\4.5\release\"
#     Import-Module .\log4net.dll
#     Pop-Location
# } else {
#     Write-Verbose -Message "Module already loaded"
# }

#nuget install log4net -Version 1.2.13.0 -OutputDirectory $Directory
}

function Unregister-ExtraPackages {
    [CmdletBinding()]
    param(
    )

    if ($registered) {
        Write-Debug -Message "Unregistering handler"
        [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($script:OnAssemblyResolve)
        $script:registered = $false
    } else {
        Write-Debug -Message "Handler is not registered"
    }
}

function Get-AllModules {
    [CmdletBinding()]
    param(
    )

    return $config
}

Export-ModuleMember -Function Register-ExtraPackages,Unregister-ExtraPackages,Get-AllModules
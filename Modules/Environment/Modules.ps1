function script:LoadModule {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    try {
        Import-Module -Name $Name
    }
    catch [System.Management.Automation.ParameterBindingValidationException]{
        # TODO: Some times the first import fails; let's try a second time
        Write-Warning -Message "Trying to import $Name for the second time" -ErrorAction SilentlyContinue
        Import-Module -Name $Name
    }
}

# Do not rename to Install-Module, as it may collide with the available commands
function script:InstallModule {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    # There are a number of ways to install the package. Not sure which order is the best,
    # or the differences between them.
    if (Get-Command -Name Install-Module -Module PowerShellGet -ErrorAction SilentlyContinue) {
        PowerShellGet\Install-Module -Name $Name -Force -AllowClobber -Repository PSGallery
    } elseif (Get-Command -Name Install-Module -Module PsGet -ErrorAction SilentlyContinue) {
        PsGet\Install-Module -ModuleName $Name -Force
    } elseif (Get-Command -Name Install-Package -Module PackageManagement -ErrorAction SilentlyContinue) {
        PackageManagement\Install-Package -Name $Name -Force        
    } elseif (Get-Command -Name Install-Module -ErrorAction SilentlyContinue) {
        Install-Module $Name
    } else {
        Write-Error -Message "Cannot find facility to install module $Name; please install manually"
    }
}

function Get-ModuleInstall {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ModuleName,

        [switch]
        $Local
    )
    BEGIN {
        [string]$lastCheckedFile = ".LastChecked"
        if ((Get-Variable -Name RootOfPowershellDirectory -ErrorAction SilentlyContinue) -ne $null) {
            $lastCheckedFile = Join-Path -Path $RootOfPowershellDirectory -ChildPath $lastCheckedFile
        }
        Write-Verbose -Message "Will check modules against the timestamps in $LastCheckedFile"

        [System.Collections.Hashtable]$lastChecked = @{}
        [System.TimeSpan]$timeBetweenChecks = [System.TimeSpan]::FromDays(7)

        if (Test-Path -Path $LastCheckedFile) {
            Get-Content -Path $lastCheckedFile | ForEach-Object -Process {
                $entries = $_.Split()
                $key = $entries[0]
                $last = [System.DateTime]::Parse($entries[1])
                Write-Verbose -Message "Adding $key with last timestamp: $last"
                $lastChecked.Add($key, $last)
            }
        }

        $myIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $wp = New-Object Security.Principal.WindowsPrincipal($myIdentity)
        $isAdmin = $wp.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

        Write-Verbose -Message ("Module path is: " + $Env:PSModulePath)
    }
    PROCESS {
        foreach($module in $ModuleName) {
            Write-Verbose -Message "Checking for $module"

            $isLoaded = (Get-Module -Name $module) -ne $null
            $isAvailable = (Get-Module $module -ListAvailable) -ne $null

            if ($isAvailable -and (-not $isLoaded)) {
                Write-Verbose -Message "Module $module is available but not loaded; trying to load"
                LoadModule -Name $module 
            }
            elseif (-not $isAvailable) {
                $isInRepo = Find-Package -Name $module -Source PSGallery
                if ($null -eq $isInRepo) {
                    Write-Warning -Message "Module $module is not in PSGallery; consider installing manually"
                } elseif ($isAdmin) {
                    # The module is available, and the script is running in admin mode: try to install
                    Write-Verbose -Message "Trying to install package $module"
                    InstallModule -Name $module
                    LoadModule -Name $module              
                } else {
                    # The module is available, but we are not in elevated mode
                    Write-Warning -Message "Please install module $module in elevated mode, e.g. Install-Module $module, or run again elevated"
                }
            } else {
                # It is available and loaded; nothing to do.
            }
            
            [PSModuleInfo[]]$current = Get-Module -Name $module
            $isLoaded = $current -ne $null

            if (-not $isLoaded) {
                continue
            }

            if ($current.Length -gt 1) {
                Write-Warning -Message "Multiple installations of $module detected"
            }
            $current = $current[0]

            if ($Local) {
                continue
            }

            if ($lastChecked.ContainsKey($module)) {
                $last = $lastChecked[$module]

                Write-Verbose -Message "Module $module is installed, last time checked: $last"
                $now = Get-Date
                $diff = $now - $last

                if ($diff.CompareTo($timeBetweenChecks) -gt 0) {
                    Write-Verbose -Message "Checking for update for module $module"
                    $available = Find-Package -Name $module -Source PSGallery

                    if ( ($null -ne $available) -and ($current.Version -ne $available.Version) ) {
                        $currentVersion = $current.Version
                        $availableVersion = $available.Version
                    
                        Write-Warning -Message "Consider upgrading package $module (current: $currentVersion, available: $availableVersion) ..."
                    } else {
                        # Installed version is updated
                        $now = Get-Date
                        $lastChecked[$module] = $now
                    }
                } else {
                    Write-Verbose -Message "No need to check again for module $module"
                }
            } else {
                Write-Verbose -Message "Module $module is installed, but we do not have a record of checking its version"
                $available = Find-Package -Name $module -Source PSGallery -ErrorAction SilentlyContinue

                if ($null -eq $available) {
                    Write-Error -Message "Cannot find $module in online repository"
                } elseif ($current.Version -ne $available.Version) {
                    $currentVersion = $current.Version
                    $availableVersion = $available.Version
                    Write-Warning -Message "Consider upgrading $module (current: $currentVersion, available: $availableVersion) ...."
                } else {
                    $now = Get-Date
                    $lastChecked.Add($module, $now)
                }
            }
        }
    }
    END {
        if (Test-Path -Path $lastCheckedFile) {
            Remove-Item -Path $lastCheckedFile -Force
        }

        foreach ($item in $lastChecked.GetEnumerator())
        {
            $key = $item.Key
            $date = $item.Value.ToString("o")
            $entry = "$key`t$date"
            $entry | Out-File -Encoding ascii -Append -FilePath $lastCheckedFile
        }
    }
}
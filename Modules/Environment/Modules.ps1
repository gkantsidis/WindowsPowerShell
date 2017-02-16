function Get-ModuleInstall {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$True,
                   ValueFromPipelineByPropertyName=$True)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ModuleName
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

        Write-Verbose -Message ("Module path is: " + $Env:PSModulePath)
    }
    PROCESS {
        foreach($module in $ModuleName) {
            Write-Verbose -Message "Checking for $module"

            try {
                Import-Module -Name $module
            }
            catch [System.Management.Automation.ParameterBindingValidationException]{
                # TODO: Some times the first import fails; let's try a second time
                Write-Warning -Message "Trying to import $module for the second time" -ErrorAction SilentlyContinue
                Import-Module -Name $module
            }
            
            $current = Get-Module -Name $module
            if ($null -eq $current) {
                Write-Warning -Message "Cannot get module $module; trying a second time"
                $current = Get-Module -Name $module -ListAvailable
            }

            if ($null -eq $current) {
                Write-Verbose -Message "Module $module is not installed"

				if (Get-Module -Name PackageManagement) {
					$available = Find-Package -Name $module -Source PSGallery # | Where-Object -Property ProviderName -eq PSModule

					if ($null -eq $available) {
						Write-Warning -Message "Consider installing package $module ..."
						# Write-Host -Object "... using: Find-Package $module | ? ProviderName -eq PSModule | Install-Package -Force (in elevated prompt)"
					}
				} else {
					Write-Warning -Message "Consider installing PackageManagement module"
					Write-Warning -Message "Consider installing $module module"
				}
            } elseif ($lastChecked.ContainsKey($module)) {            
                $last = $lastChecked[$module]

                Write-Verbose -Message "Module $module is installed, last time checked: $last"
                $now = Get-Date
                $diff = $now - $last

                if ($diff.CompareTo($timeBetweenChecks) -gt 0) {
                    Write-Verbose -Message "Checking for update for module $module"
                    $available = Find-Package -Name $module # | Where-Object -Property ProviderName -eq PSModule

                    if ( ($null -ne $available) -and ($current.Version -ne $available.Version) ) {
                        $currentVersion = $current.Version
                        $availableVersion = $available.Version
                    
                        Write-Warning -Message "Consider upgrading package $module (current: $currentVersion, available: $availableVersion) ..."
                        # Write-Host -Object "... using: Find-Package $module | ? ProviderName -eq PSModule | Install-Package -Force (in elevated prompt)"
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
                # $available = Find-Package -Name $module | Where-Object -Property ProviderName -eq PSModule
                $available = Find-Package -Name $module -Source PSGallery -ErrorAction SilentlyContinue

                if ($null -eq $available) {
                    Write-Error -Message "Cannot find $module in online repository"
                } elseif ($current.Version -ne $available.Version) {
                    $currentVersion = $current.Version
                    $availableVersion = $available.Version
                    Write-Warning -Message "Consider upgrading $module (current: $currentVersion, available: $availableVersion) [look also for multiple installations of pscx, e.g. with choco] ...."
                    # Write-Host -Object "... using: Find-Package $module | ? ProviderName -eq PSModule | Install-Package -Force (in elevated prompt)"
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
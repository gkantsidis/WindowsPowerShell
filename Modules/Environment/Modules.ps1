function CheckInstall-Module {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "CheckInstall-Module")]
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
    }
    PROCESS {
        foreach($module in $ModuleName) {
            Write-Verbose -Message "Checking for $module"

            Import-Module -Name $module -ErrorAction SilentlyContinue
            $current = Get-Module -Name $module

            if ($null -eq $current) {
                Write-Verbose -Message "Module $module is not installed"

                $available = Find-Package -Name $module | Where-Object -Property ProviderName -eq PSModule

                if ($null -eq $available) {
                    Write-Host -Object "Consider installing $module ..."
                    Write-Host -Object "... using: Find-Package $module | ? ProviderName -eq PSModule | Install-Package -Force (in elevated prompt)"
                }
            } elseif ($lastChecked.ContainsKey($module)) {            
                $last = $lastChecked[$module]

                Write-Verbose -Message "Module $module is installed, last time checked: $last"
                $now = Get-Date
                $diff = $now - $last

                if ($diff.CompareTo($timeBetweenChecks) -gt 0) {
                    Write-Verbose -Message "Checking for update for module $module"
                    $available = Find-Package -Name $module | Where-Object -Property ProviderName -eq PSModule

                    if ( ($null -ne $available) -and ($current.Version -ne $available.Version) ) {
                        Write-Host -Object "Consider upgrading $module ..."
                        Write-Host -Object "... using: Find-Package $module | ? ProviderName -eq PSModule | Install-Package -Force (in elevated prompt)"
                    } else {
                        # Installed version is updated
                        $now = Get-Date
                        $lastChecked[$module] = $now
                    }
                } else {
                    Write-Verbose -Message "No need to check again for module $module"
                }
            } else {
                Write-Verbose -Message "Module $module is installed, but we do not have a record of checking of its version"
                # $available = Find-Package -Name $module | Where-Object -Property ProviderName -eq PSModule
                $available = Find-Package -Name $module

                if ($null -eq $available) {
                    Write-Error -Message "Cannot find $module in online repository"
                } elseif ($current.Version -ne $available.Version) {
                    Write-Host -Object "Consider upgrading $module ..."
                    Write-Host -Object "... using: Find-Package $module | ? ProviderName -eq PSModule | Install-Package -Force (in elevated prompt)"
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
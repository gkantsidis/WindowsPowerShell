function CheckInstall-Module {
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

        if (Test-Path $LastCheckedFile) {
            Get-Content $lastCheckedFile | ForEach-Object -Process {
                $entries = $_.Split()
                $key = $entries[0]
                $last = [System.DateTime]::Parse($entries[1])
                Write-Verbose "Adding $key with last timestamp: $last"
                $lastChecked.Add($key, $last)
            }
        }
    }
    PROCESS {
        foreach($module in $ModuleName) {
            Write-Verbose "Checking for $module"

            Import-Module -Name $module -ErrorAction SilentlyContinue
            $current = Get-Module -Name $module

            if ($current -eq $null) {
                Write-Verbose "Module $module is not installed"

                $available = Find-Package -Name $module | ? ProviderName -eq PSModule

                if ($available -ne $null) {
                    Write-Host "Consider installing $module ..."
                    Write-Host "... using: Find-Package $module | ? ProviderName -eq PSModule | Install-Package -Force (in elevated prompt)"
                }
            } elseif ($lastChecked.ContainsKey($module)) {            
                $last = $lastChecked[$module]

                Write-Verbose "Module $module is installed, last time checked: $last"
                $now = Get-Date
                $diff = $now - $last

                if ($diff.CompareTo($timeBetweenChecks) -gt 0) {
                    Write-Verbose "Checking for update for module $module"
                    $available = Find-Package -Name $module | ? ProviderName -eq PSModule

                    if ( ($available -ne $null) -and ($current.Version -ne $available.Version) ) {
                        Write-Host "Consider upgrading $module ..."
                        Write-Host "... using: Find-Package $module | ? ProviderName -eq PSModule | Install-Package -Force (in elevated prompt)"
                    } else {
                        # Installed version is updated
                        $now = Get-Date
                        $lastChecked[$module] = $now
                    }
                } else {
                    Write-Verbose "No need to check again for module $module"
                }
            } else {
                Write-Verbose "Module $module is installed, but we do not have a record of checking of its version"
                $available = Find-Package -Name $module | ? ProviderName -eq PSModule

                if ($available -eq $null) {
                    Write-Error "Cannot find $module in online repository"
                } elseif ($current.Version -ne $available.Version) {
                    Write-Host "Consider upgrading $module ..."
                    Write-Host "... using: Find-Package $module | ? ProviderName -eq PSModule | Install-Package -Force (in elevated prompt)"
                } else {
                    $now = Get-Date
                    $lastChecked.Add($module, $now)
                }
            }
        }
    }
    END {
        if (Test-Path $lastCheckedFile) {
            Remove-Item $lastCheckedFile -Force
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
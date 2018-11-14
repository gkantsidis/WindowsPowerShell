#Requires  -RunAsAdministrator

# Goal: compile assemblies to improve PS profile loading time
# Source: https://blogs.msdn.microsoft.com/powershell/2008/09/02/speeding-up-powershell-startup-updating-update-gac-ps1/


[CmdletBinding()]
param(
    [switch]$NoDependencies
)

Set-Alias ngen (Join-Path ([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) ngen.exe)

[AppDomain]::CurrentDomain.GetAssemblies() |
    ForEach-Object -Process {
        $location = $_.Location
        if ($_.FullName.Contains("Anonymously Hosted DynamicMethods Assembly")) {
            Write-Debug -Message "Ignoring anonymous: $_"
        } elseif ([string]::IsNullOrWhitespace($location)) {
            Write-Warning -Message "Empty location for $_; ignoring"
        } else {
            $Name = (Split-Path $_.location -leaf)
            if ([System.Runtime.InteropServices.RuntimeEnvironment]::FromGlobalAccessCache($_))
            {
                Write-Verbose -Message "Already GACed: $Name"
            }
            else
            {
                Write-Verbose -Message "NGENing      : $Name (from $location)"
                if ($NoDependencies) {
                    $result = ngen install $_.location /NoDependencies
                } else {
                    $result = ngen install $_.location
                }

                $result | ForEach-Object -Process {"`t$_"}
            }
        }
      }
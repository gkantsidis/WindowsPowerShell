#Requires -Module Pipeworks

[CmdletBinding()]
param(
    $Directory = $PSScriptRoot
)

if (-not (Test-Path -Path "log4net-1.2.15" -PathType Container)) {
    $filename = [System.IO.FileInfo]::new([System.IO.Path]::GetTempFileName())
    $filename = Join-Path -Path $filename.DirectoryName -ChildPath ($filename.BaseName + ".zip")
    Try {
        Invoke-WebRequest `
            -Uri "http://archive.apache.org/dist/logging/log4net/binaries/log4net-1.2.15-bin-newkey.zip" `
            -OutFile $filename
        Expand-Zip -ZipPath $filename -OutputPath $Directory
    }
    Finally {
        if (Test-Path -Path $filename) {
            Remove-Item -Path $filename -Force
        }
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

if (-not (Test-Path Env:CUSTOM_ASSEMBLY_RESOLVE_INITIALIZED)) {
    [System.AppDomain]::CurrentDomain.add_AssemblyResolve($OnAssemblyResolve)
    $Env:CUSTOM_ASSEMBLY_RESOLVE_INITIALIZED = "TRUE"
} else {
    Write-Verbose -Message "Handler already registered"
}

if (-not (Get-Module log4net)) {
    Push-Location -Path "$PSScriptRoot\log4net-1.2.15\bin\net\4.5\release\"
    Import-Module .\log4net.dll
    Pop-Location
} else {
    Write-Verbose -Message "Module already loaded"
}

#nuget install log4net -Version 1.2.13.0 -OutputDirectory $Directory
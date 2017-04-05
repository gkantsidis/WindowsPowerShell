#Requires -Version 3

function Install-Scoop {
    [CmdletBinding()]
    Param(
        [switch]
        $AddExtraBucket
    )

    $securityProblem = $false

    if (-not (Get-Command -Name scoop -ErrorAction SilentlyContinue)) {
        try {
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -ErrorAction SilentlyContinue
        }
        catch [System.Security.SecurityException] {
            Write-Verbose -Message "Caught a SecurityException. We will ignore for now."
            $securityProblem = $true
        }

        Invoke-Expression (new-object net.webclient).downloadstring('https://get.scoop.sh')
    } else {
        Write-Verbose -Message "Scoop is already installed"
    }

    if ((-not (Get-Command -Name scoop -ErrorAction SilentlyContinue)) -and $securityProblem) {
        Write-Verbose -Message "Tried to install, but failed due to a security problem"

        $erroractionpreference='stop' # quit if anything goes wrong
        # get core functions
        $core_url = 'https://raw.github.com/lukesampson/scoop/master/lib/core.ps1'
        Write-Output 'Initializing...'
        # The following downloaded and installed the commands that will be used below
        Invoke-Expression (new-object net.webclient).downloadstring($core_url)

        # prep
        if(installed 'scoop') {
            write-host "Scoop is already installed. Run 'scoop update' to get the latest version." -f red
            # don't abort if invoked with iexâ€”â€”that would close the PS session
            if($myinvocation.mycommand.commandtype -eq 'Script') { return } else { exit 1 }
        }
        $dir = ensure (versiondir 'scoop' 'current')

        # download scoop zip
        $zipurl = 'https://github.com/lukesampson/scoop/archive/master.zip'
        $zipfile = Join-Path -Path $dir -ChildPath "scoop.zip"
        Write-Verbose -Message 'Downloading...'
        Invoke-WebRequest -Uri $zipurl -OutFile $zipfile

        Write-Verbose -Message 'Extracting...'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $extractdirectory = Join-Path -Path $dir -ChildPath "_scoop_extract"
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $extractdirectory)
        Copy-Item "$dir\_scoop_extract\scoop-master\*" $dir -r -force
        Remove-Item "$dir\_scoop_extract" -r -force
        Remove-Item $zipfile

        Write-Output 'Creating shim...'
        shim "$dir\bin\scoop.ps1" $false

        ensure_robocopy_in_path
        ensure_scoop_in_path
        success 'Scoop was installed successfully!'
        Write-Output "Type 'scoop help' for instructions."
    }

    $scoop = Get-Command -Name scoop -ErrorAction SilentlyContinue
    if (-not $scoop) {
        Write-Error -Message "Cannot install Scoop; quitting"
        break
    }

    # Ensure that Scoop is in the path

    $directory = Split-Path -Path $scoop.Path -Parent
    [string]$userPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
    [string]$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)

    $userPath = $userPath.ToUpperInvariant()
    $machinePath = $machinePath.ToUpperInvariant()

    if (($userPath.IndexOf($directory.ToUpperInvariant()) -lt 0) -and ($machinePath.IndexOf($directory.ToUpperInvariant()) -lt 0)) {
        Write-Verbose -Message "Scoop is not in the environment variable; adding ..."
        if (($null -eq $userPath) -or ($userPath.EndsWith(";"))) {
            $newPath = $userPath + "$directory;"
        } else {
            $newPath = $userPath + ";$directory;"
        }

        [System.Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::User)
    }

    if ($AddExtraBucket) {
        [string[]]$buckets = scoop bucket list
        if (-not ($buckets -contains "christos-public-bucket")) {
            Write-Verbose -Message "My public bucket is not in the list; adding"
            scoop bucket add christos-public-bucket https://github.com/gkantsidis/scoop-public-bucket
        }
    }
}
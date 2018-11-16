function Get-Status {
    [CmdletBinding()]
    param (
        [ValidateScript({Test-Path -Path $_})]
        [string]
        $Path = ((Get-Location).ProviderPath),

        [switch]
        $DoNotRefresh
    )

    $manifest = Get-Manifest -Path $Path -DoNotRefresh:$DoNotRefresh

    foreach ($project in $manifest.Project.Values) {
        $name = $project.Name
        $directory = Join-Path -Path $manifest.RootDirectory -ChildPath $project.Path
        if (Test-Path -Path $directory -PathType Container) {
            Write-Verbose "$name found in $directory"
        } else {
            Write-Warning "$name not found; expected in $directory"
        }
    }
}

function Sync-Collection {
    [CmdletBinding()]
    param (
        [ValidateScript({Test-Path -Path $_})]
        [string]
        $Path = ((Get-Location).ProviderPath),

        [switch]$CreateOnly,

        [switch]
        $DoNotRefresh
    )

    # TODO: Implement WhatIf
    # TODO: Be a bit smarter when syncing to detect conflicts
    # TODO: Provide alternative input through the manifest object

    $manifest = Get-Manifest -Path $Path -DoNotRefresh:$DoNotRefresh
    if ($manifest -eq $null) {
        Write-Error -Message "Cannot get manifest"
        return
    }

    foreach ($project in $manifest.Project.Values) {
        Write-Verbose -Message "Processing: $project"
        $name = $project.Name
        $directory = Join-Path -Path $manifest.RootDirectory -ChildPath $project.Path
        if (Test-Path -Path $directory -PathType Container) {
            if (-not $CreateOnly) {
                Write-Warning -Message "Syncing $name"
                Push-Location -Path $directory
                git fetch --all
                $status = Get-GitStatus

                if ($status.HasWorking) {
                    Write-Warning "Repo $name is dirty"
                }
                git pull
                Pop-Location
            }
        } else {
            $r = $manifest.Remote[$project.Remote]
            $url = "{0}/{1}" -f $r,$project.Name
            Write-Warning -Message "Creating $name from $url into $directory"
            git clone --recurse-submodules $url $directory
        }
    }
}
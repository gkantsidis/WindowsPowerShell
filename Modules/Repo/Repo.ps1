function Find-Manifest {
    [CmdletBinding()]
    param (
        [ValidateScript({Test-Path -Path $_})]
        [string]
        $Path = ((Get-Location).ProviderPath)
    )

    begin {
        Write-Verbose -Message "Searching for manifest in: $Path"
    }

    process {
        $found = $false
        $search = $true
        while ($search) {
            $candidate = Join-Path -Path $Path -ChildPath ".repo"
            if (Test-Path -Path $candidate -PathType Container) {
                Write-Verbose -Message "Found .repo in $candidate"

                $manifest = Join-Path -Path $candidate -ChildPath manifest |
                            Join-Path -ChildPath "default.xml"

                if (Test-Path -Path $manifest -PathType Leaf) {
                    $found = $true
                    $search = $false
                    return $manifest
                }
            } else {
                $current = Get-Item -Path $Path
                $parent = $current.Parent
                if ($parent -eq $null) {
                    Write-Error -Message "Cannot find manifest file"
                    $search = $false
                    return
                } else {
                    $Path = $parent.FullName
                }
            }
        }
    }

    end {
    }
}

function Get-ManifestXml {
    [CmdletBinding()]
    param (
        [ValidateScript({Test-Path -Path $_})]
        [string]
        $Path = ((Get-Location).ProviderPath),

        [switch]
        $DoNotRefresh
    )

    $manifestFile = Find-Manifest -Path $Path
    if ($manifestFile -ne $null) {
        if (-not $DoNotRefresh) {
            Write-Verbose -Message "Refreshing manifest"
            $parent = (Get-Item $manifestFile).DirectoryName
            Push-Location -Path $parent
            git pull
            Pop-Location
        }

        [xml]$manifest = Get-Content -Path $manifestFile
        return $manifest
    } else {
        Write-Error -Message "Cannot find manifest in $Path"
    }
}

class Project {
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string]$Path
    [ValidateNotNullOrEmpty()][string]$Remote
    [ValidateNotNullOrEmpty()][string[]]$Groups

    Project(
        [string]$name,
        [string]$path,
        [string]$remote,
        [string]$groups
    )
    {
        $this.Name      = $name
        $this.Path      = $path
        $this.Remote    = $remote
        $this.Groups    = $groups.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)
    }

    [String] ToString()
    {
        return ("{0} from {1}:{2}" -f $this.Path,$this.Remote,$this.Name)
    }
}

class Repo {
    [ValidateNotNullOrEmpty()]
    [string]$RootDirectory

    [ValidateNotNullOrEmpty()]
    [string]$ManifestFile

    [ValidateNotNullOrEmpty()]
    [string]$ManifestDirectory

    [ValidateNotNull()]
    [xml]$Manifest

    [Hashtable]$Remote
    [Hashtable]$Project

    Repo(
        [string]$rootDirectory,
        [string]$file,
        [xml]$manifest)
    {
        $this.RootDirectory     = Resolve-Path -Path $rootDirectory
        $this.ManifestFile      = Resolve-Path -Path $file
        $this.ManifestDirectory = Resolve-Path -Path ((Get-Item $file).DirectoryName)
        $this.Manifest          = $manifest

        $this.Remote  = @{}
        $this.Project = @{}

        $this.Populate()
    }

    Clean()
    {
        $this.Remote  = @{}
        $this.Project = @{}
    }

    Populate()
    {
        foreach ($remote in $this.Manifest.manifest.remote) {
            $this.Remote.Add($remote.Name, $remote.fetch)
        }

        foreach($project in $this.Manifest.manifest.project) {
            if ([string]::IsNullOrWhitespace($project.name)) {
                Write-Error -Message "Cannot find a valid project name for $project"
            } elseif ([string]::IsNullOrWhitespace($project.path)) {
                Write-Error -Message "Cannot find a valid project path for $project"
            } else {
                $pr = [Project]::new($project.name, $project.path, $project.remote, $project.groups)
                $this.Project.Add($project.path, $pr)
            }
        }
    }

    Update([switch]$DoNotRefresh)
    {
        Push-Location -Path $this.ManifestDirectory
        if (-not $DoNotRefresh) {
            git pull
        }
        [xml]$this.Manifest = Get-Content -Path $this.ManifestFile
        Pop-Location
        $this.Populate()
    }
}

function Get-Manifest {
    [CmdletBinding()]
    param (
        [ValidateScript({Test-Path -Path $_})]
        [string]
        $Path = ((Get-Location).ProviderPath),

        [switch]
        $DoNotRefresh
    )


    $manifestFile = Find-Manifest -Path $Path
    [xml]$manifest = Get-ManifestXml -Path $Path -DoNotRefresh:$DoNotRefresh
    $manifestLocation = (Get-Item -Path $manifestFile).DirectoryName
    $root = Join-Path -Path $manifestLocation -ChildPath ".." | Join-Path -ChildPath ".."
    $repo = [Repo]::new($root, $manifestFile, $manifest)
    $repo
}
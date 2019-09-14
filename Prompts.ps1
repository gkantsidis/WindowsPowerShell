function global:Get-TruncatedPath {
    param(
        [ValidateScript({$_ -gt 10})]
        [int]$MaxPath = 20
    )

    $pp = $pwd.ProviderPath

    if ($pp.StartsWith("\\")) {
        $endhost = $pp.IndexOf('\', 2)
        $host_name = $pp.Substring(2, $endhost-2)
        if ($host_name -notmatch "(\d+).(\d+).(\d+).(\d+)") {
            $hi = $host_name.IndexOf('.')
            if ($hi -gt 0) {
                $host_name = $host_name.Substring(0, $hi)
            }
        }
        $host_name = '[' + $host_name + '] '
        Write-Host $host_name -NoNewLine -ForegroundColor 'DarkGreen'

        $base_path_index = $pp.IndexOf('\', $endhost+1)
        if ($base_path_index -le 0) {
            $path = "\"
            $drive = $pp.Substring($endhost + 1).Replace('$', '')
        } else {
            $path = $pp.Substring($base_path_index)
            $drive = $pp.Substring($endhost + 1, $base_path_index - $endhost - 2)
        }
    } else {
        $host_name = ""
        $drive = $pwd.Drive.Name
        $path = $pwd.Path.Substring($drive.Length + 1)
    }

    $adjusted = $false
    $lastIndex = $path.Length - $MaxPath
    if ($lastIndex -gt 0) {
        $lastIndex = $path.LastIndexOf("\", $lastIndex - 1)
        $adjusted = $true
    }
    if ($adjusted) {
        $oldPath = $path
        $path = "..." + $path.Substring($lastIndex)
        if ($path.Length -ge $oldPath.Length) {
            $path = $oldPath
        }
    }

    return ("{0}:{1}" -f $drive,$path)
}

function global:Set-NormalPrompt {
    param(
        [switch]$DoNotRemoveAlias,
        [switch]$NoColor
    )

    # Some modules (e.g. xUtility) create this alias to modify the prompt
    if(-not $DoNotRemoveAlias) {
        Remove-Item Alias:\Prompt -ErrorAction SilentlyContinue
    }

    if ($NoColor) {
        function global:prompt {
            $p = "{0} λ" -f (global:Get-TruncatedPath)
            Write-Host $p -NoNewLine
            return " "
        }
    } else {
        function global:prompt {
            $p = "{0} λ" -f (global:Get-TruncatedPath)
            Write-Host $p -NoNewLine -ForegroundColor "DarkGray"
            return " "
        }
    }
}

function global:Set-GitPrompt {
    param(
        [switch]$DoNotRemoveAlias,
        [switch]$NoColor
    )

    # Some modules (e.g. xUtility) create this alias to modify the prompt
    if(-not $DoNotRemoveAlias) {
        Remove-Item Alias:\Prompt -ErrorAction SilentlyContinue
    }

    if ($NoColor) {
        function global:prompt {
            $realLASTEXITCODE = $LASTEXITCODE
            Write-Host($pwd.ProviderPath) -nonewline
            Write-VcsStatus
            $global:LASTEXITCODE = $realLASTEXITCODE
            Write-Host "`nλ" -NoNewLine
            return " "
        }
    } else {
        function global:prompt {
            $realLASTEXITCODE = $LASTEXITCODE
            Write-Host($pwd.ProviderPath) -nonewline
            Write-VcsStatus
            $global:LASTEXITCODE = $realLASTEXITCODE
            Write-Host "`nλ" -NoNewLine -ForegroundColor "DarkGray"
            return " "
        }
    }
}

if ($null -ne (Get-Module -Name PowerLine -ListAvailable)) {
    if (-not (Get-Module -Name PowerLine)) {
        Import-Module -Name PowerLine
    }

    function global:Set-NormalPrompt2 {
        Set-PowerLinePrompt -Prompt { Get-TruncatedPath } -Colors "#00DDFF","#0066FF" -PowerLineFont -FullColor
    }
}

try {
    Set-NormalPrompt
}
catch [System.Management.Automation.SessionStateUnauthorizedAccessException] {
    Write-Verbose -Message "The prompt seems to be set as readonly, removing ..."
    Remove-Item -Path Function:prompt -Force
    Set-NormalPrompt
}

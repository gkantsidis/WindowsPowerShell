function global:prompt {
    $maxPath = 20
    $drive = $pwd.Drive.Name
    $path = $pwd.Path.Substring($drive.Length + 1)
    $adjusted = $false
    $lastIndex = $path.Length - $maxPath
    if ($lastIndex -gt 0) {
        $lastIndex = $path.LastIndexOf("\", $lastIndex - 1)
        $adjusted = $true
    }
    if ($adjusted) {
        $path = "..." + $path.Substring($lastIndex)
    }
    $p = $drive + ":" + $path + " λ"
    Write-Host $p -NoNewLine -ForegroundColor "DarkGray"
    return " "
}

function global:Set-NormalPrompt {
    function global:prompt {
        $maxPath = 20
        $drive = $pwd.Drive.Name
        $path = $pwd.Path.Substring($drive.Length + 1)
        $adjusted = $false
        $lastIndex = $path.Length - $maxPath
        if ($lastIndex -gt 0) {
            $lastIndex = $path.LastIndexOf("\", $lastIndex - 1)
            $adjusted = $true
        }
        if ($adjusted) {
            $path = "..." + $path.Substring($lastIndex)
        }
        $p = $drive + ":" + $path + " λ"
        Write-Host $p -NoNewLine -ForegroundColor "DarkGray"
        return " "
    }
}

function global:Set-GitPrompt {
    function global:prompt {
        $realLASTEXITCODE = $LASTEXITCODE
        Write-Host($pwd.ProviderPath) -nonewline
        Write-VcsStatus
        $global:LASTEXITCODE = $realLASTEXITCODE
        Write-Host "`nλ" -NoNewLine -ForegroundColor "DarkGray"
        return " "
    }
}
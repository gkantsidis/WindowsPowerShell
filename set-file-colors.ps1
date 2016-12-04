function script:Write-Color-LS
    {
        param (
            [string]$color = "white",
            $file,

            $rootDirectory
        )

        $length = ""
        $hasLength = Get-Member -InputObject $file -Name Length -MemberType Properties
        if ($hasLength) {
            $length = $file.Length
            if ($length -ge 1000) {
                $length = $length / 1000
                if ($length -ge 1000) {
                    $length = $length  / 1000
                    if ($length -ge 1000) {
                        $length = $length / 1000
                        $length = $length.ToString("F2") + "G"
                    } else {
                        $length = $length.ToString("F2") + "M"    
                    }
                } else {
                    $length = $length.ToString("F2") + "K"
                }
            } else {
                # do nothing; length is in bytes
            }
        }

        $related = ""
        if ($file -is [System.IO.DirectoryInfo]) {
            $related = $file.Parent.FullName.Replace($rootDirectory.ProviderPath, "")
        } elseif ($file -is [System.IO.FileInfo]) {
            $related = $file.Directory.FullName.Replace($rootDirectory.ProviderPath, "")
        }
        if ($related.StartsWith("\")) {
            $related = $related.Substring(1)
        }

        if ([System.String]::IsNullOrEmpty($related)) {
            Write-host ("{0,-7} {1,25} {2,10} {3}" -f $file.mode, ([String]::Format("{0,10}  {1,8}", $file.LastWriteTime.ToString("d"), $file.LastWriteTime.ToString("t"))), $length, $file.name) -foregroundcolor $color
        } else {
            Write-host ("{0,-7} {1,25} {2,10} {3}" -f $file.mode, ([String]::Format("{0,10}  {1,8}", $file.LastWriteTime.ToString("d"), $file.LastWriteTime.ToString("t"))), $length, $file.name) -foregroundcolor $color -NoNewline
            Write-Host (" [{0}]" -f $related) -ForegroundColor Gray
        }
    }

New-CommandWrapper -Name Out-Default `
-Begin {
    $notfirst = $false
} `
-Process {
    $regex_opts = ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)


    $compressed = New-Object System.Text.RegularExpressions.Regex(
        '\.(zip|tar|gz|rar|jar|war)$', $regex_opts)
    $executable = New-Object System.Text.RegularExpressions.Regex(
        '\.(exe|bat|cmd|py|pl|ps1|psm1|vbs|rb|reg)$', $regex_opts)
    $text_files = New-Object System.Text.RegularExpressions.Regex(
        '\.(txt|cfg|conf|ini|csv|log|xml)$', $regex_opts)
    $source_files = New-Object System.Text.RegularExpressions.Regex(
        '\.(java|c|cpp|cs|fs|fsi|ml|mli)$', $regex_opts)

    if(($_ -is [System.IO.DirectoryInfo]) -or ($_ -is [System.IO.FileInfo]))
    {
        if(-not ($notfirst)) 
        {
           Write-Host
           Write-Host "    Directory: " -noNewLine
           Write-Host " $(pwd)`n" -foregroundcolor "Magenta"           
           Write-Host "Mode                LastWriteTime     Length Name"
           Write-Host "----                -------------     ------ ----"
           $notfirst=$true
        }

        $rootDirectory = $(pwd)
        if ($_ -is [System.IO.DirectoryInfo]) 
        {
            Write-Color-LS "Magenta" $_ $rootDirectory
        }
        elseif ($compressed.IsMatch($_.Name))
        {
            Write-Color-LS "DarkGreen" $_ $rootDirectory
        }
        elseif ($executable.IsMatch($_.Name))
        {
            Write-Color-LS "Red" $_ $rootDirectory
        }
        elseif ($text_files.IsMatch($_.Name))
        {
            Write-Color-LS "Yellow" $_ $rootDirectory
        }
        elseif ($source_files.IsMatch($_.Name))
        {
            Write-Color-LS "DarkYellow" $_ $rootDirectory
        }
        else
        {
            Write-Color-LS "White" $_ $rootDirectory
        }

        $_ = $null
    }
    elseif ($_ -is [System.Collections.Hashtable])
    {
        Write-Host "Key                        " -NoNewLine -ForegroundColor "Magenta"
        Write-Host "  Value"                                -ForegroundColor "DarkGreen"
        Write-Host "-------------------------- --------------------------"
        $entries = $_.GetEnumerator()
        $entries | ForEach-Object -Process {
            $key = $_.Name
            $value = $_.Value
            Write-Host ("{0,-25}" -f $key) -NoNewLine -ForegroundColor "Magenta"
            Write-Host " = " -NoNewLine
            Write-Host ("{0,-25}" -f $value) -ForegroundColor "DarkGreen"
        }
        $_ = $null
    }
} `
-End {
    write-host ""
}
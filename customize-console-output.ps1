$script:separator = @( [System.IO.Path]::DirectorySeparatorChar; [System.IO.Path]::AltDirectorySeparatorChar )

function script:Get-RelativePath {
    [CmdletBinding(SupportsShouldProcess=$true )]
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $Target,

        [ValidateNotNullOrEmpty()]
        [string]
        $Base
    )

    $Target = $Target.Trim().TrimEnd($separator)
    $Base = $Base.Trim().TrimEnd($separator)
    $orig_target = $Target

    if ($Target.StartsWith("\\")) {
        $index = $Target.IndexOf([System.IO.Path]::DirectorySeparatorChar, 2)
        $host_target = $Target.Substring(2,  $index - 2)
        $Target = $Target.Substring($index + 1)
        $Target = $Target.Replace("`$", ":")
    } else {
        $host_target = $Env:COMPUTERNAME
    }

    if ($Base.StartsWith("\\")) {
        $index = $Base.IndexOf([System.IO.Path]::DirectorySeparatorChar, 2)
        $host_base = $Base.Substring(2, $index - 2)
        $Base = $Base.Substring($index + 1)
        $Base = $Base.Replace("`$", ":")
    } else {
        $host_base = $Env:COMPUTERNAME
    }

    if ($host_target -ne $host_base) {
        # They are on different machines; no point to compute relative path
        $orig_target
    } else {
        $current = $Target.Split($separator)
        $root = $Base.Split($separator)

        $min_length = [Math]::Min($current.Length, $root.Length)
        $i = 0;
        while ( ($i -lt $min_length) -and ($current[$i] -eq $root[$i])) {
            $i++
        }

        Write-Verbose -Message "Paths agree on $i"

        $up = [Math]::Max(0, $root.Length - $i)
        if ($up -gt 0) {
            Write-Verbose -Message "Going up from position $up"
            $relative = (".." + [System.IO.Path]::DirectorySeparatorChar) * $up
        } else {
            $relative = ""
        }

        if ($i -lt $current.Length) {
            Write-Verbose -Message "Going down from position $i"
            [string[]]$extra = $current[$i .. ($current.Length - 1)]
            $relative += ([System.IO.Path]::Combine($extra))
        }

        $relative = $relative.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
        if ($relative.Length -lt $orig_target.Length) {
            $relative
        } else {
            $orig_target
        }
    }
}

function script:Write-HostCustomized-Array
{
    param (
        [ValidateNotNull()]
        [Object[]]
        $Target,

        [int]
        $Tabs = 0,

        [ValidateNotNull()]
        [System.Text.StringBuilder]
        $SB
    )

    $ntabs = $Tabs + 1
    $SB.AppendFormat("{0}[", ("`t" * $Tabs)) | Out-Null
    $SB.AppendLine() | Out-Null
    for($i = 0; $i -lt $Target.Length; $i++) {
        $item = $Target[$i]
        Write-HostCustomized-Dispatcher-Internal -Target $item -Tabs $ntabs -SB $SB
    }
    $SB.AppendFormat("{0}]", ("`t" * $Tabs)) | Out-Null
    $SB.AppendLine() | Out-Null
}

function script:Write-HostCustomized-Enumerator
{
    param (
        # [ValidateNotNull()] --- Observe that this attribute will consume the enumerator and the code below will print nothing
        [System.Collections.IEnumerator]
        $Target,

        [int]
        $Tabs = 0,

        [ValidateNotNull()]
        [System.Text.StringBuilder]
        $SB
    )

    if ($null -eq $Target) {
        return
    }

    $ntabs = $Tabs + 1
    $SB.AppendFormat("{0}[", ("`t" * $Tabs)) | Out-Null
    $SB.AppendLine() | Out-Null
    while ($Target.MoveNext()) {
        $item = $Target.Current
        Write-HostCustomized-Dispatcher-Internal -Target $item -Tabs $ntabs -SB $SB
    }
    $SB.AppendFormat("{0}]", ("`t" * $Tabs)) | Out-Null
    $SB.AppendLine() | Out-Null
}

function script:Write-HostCustomized-Dispatcher-Internal
{
    param (
        $Target,

        [int]
        $Tabs = 0,

        [ValidateNotNull()]
        [System.Text.StringBuilder]
        $SB
    )

    if ($null -eq $Target) {
        # write nothing
    }
    elseif ($Target -is [Object[]]) {
        Write-HostCustomized-Array -Target $Target -Tabs $Tabs -SB $SB
    }
    elseif ($Target -is [System.Collections.IEnumerator]) {
        Write-HostCustomized-Enumerator -Target $Target -Tabs $Tabs -SB $SB
    }
    elseif ($Target -is [System.Char]) {
        $SB.AppendFormat("{0}{1}", ("`t" * $Tabs), $Target) | Out-Null
        $SB.AppendLine() | Out-Null
    }
    else {
        $v = $Target.ToString()
        $SB.AppendFormat("{0}{1}", ("`t" * $Tabs), $v) | Out-Null
        $SB.AppendLine() | Out-Null
    }
}

function script:Write-HostCustomized-Dispatcher
{
    param (
        $Target,

        [int]
        $Tabs = 0
    )

    $sb = [System.Text.StringBuilder]::new()
    Write-HostCustomized-Dispatcher-Internal -Target $Target -Tabs $Tabs -SB $sb
    $str = $sb.ToString()
    if ($str.Length -lt 100) {
        $str = [Regex]::Replace($str, "\n|\r", "")
        $str = [Regex]::Replace($str, "\t", "; ")
        $str = [Regex]::Replace($str, "\[; ", "[")
    }

    Write-Host $str
}

function script:Write-Color-LS
{
    param (
        [string]$color = "white",
        $file,
        $rootDirectory
    )

    #
    # Get a nice representation for the length of the object
    #

    $length = ""
    $hasLength = $false
    if ($file -is [System.IO.DirectoryInfo]) {
        $hasLength = $false
    } elseif ($file -is [System.IO.FileInfo]) {
        $hasLength = Get-Member -InputObject $file -Name Length -MemberType Properties
        if ($hasLength) { $length = $file.Length }
    } elseif ($file -is [System.Management.Automation.Internal.AlternateStreamData]) {
        $hasLength = $true
        $length = $file.Length
    }

    if ($hasLength) {
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

    #
    # Find the relative path of the object
    #

    $related = ""
    if ($file -is [System.IO.DirectoryInfo]) {
        if ($null -ne $file.Parent) {
            $related = Get-RelativePath -Target $file.Parent.FullName -Base $rootDirectory.ProviderPath
        } else {
            $related = ""
        }
    } elseif ($file -is [System.IO.FileInfo]) {
        $related = Get-RelativePath -Target $file.Directory.FullName -Base $rootDirectory.ProviderPath
    } elseif ($file -is [System.Management.Automation.Internal.AlternateStreamData]) {
        $realFile = Get-Item -Path $file.FileName
        $related = Get-RelativePath -Target $realFile.Directory.FullName -Base $rootDirectory.ProviderPath
    }

    if ($related.StartsWith("\")) {
        $related = $related.Substring(1)
    }

    #
    # Get a nice name
    #
    if ($file -is [System.IO.DirectoryInfo]) {
        $properName = $file.name
        $mode = $file.mode
        $lastWriteTimeDate = $file.LastWriteTime.ToString("d")
        $lastWriteTimeTime = $file.LastWriteTime.ToString("t")
    } elseif ($file -is [System.IO.FileInfo]) {
        $properName = $file.name
        $mode = $file.mode
        $lastWriteTimeDate = $file.LastWriteTime.ToString("d")
        $lastWriteTimeTime = $file.LastWriteTime.ToString("t")
    } elseif ($file -is [System.Management.Automation.Internal.AlternateStreamData]) {
        $properName = $file.PSChildName
        $mode = ""
        $lastWriteTimeDate = ""
        $lastWriteTimeTime = ""
    }

    if ([System.String]::IsNullOrEmpty($related)) {
        Write-Host ("{0,-7} {1,25} {2,10} {3}" -f $mode, ([String]::Format("{0,10}  {1,8}", $lastWriteTimeDate, $lastWriteTimeTime)), $length, $properName) -foregroundcolor $color
    } else {
        Write-Host ("{0,-7} {1,25} {2,10} {3}" -f $mode, ([String]::Format("{0,10}  {1,8}", $lastWriteTimeDate, $lastWriteTimeTime)), $length, $properName) -foregroundcolor $color -NoNewline
        if (-not [System.String]::IsNullOrWhiteSpace($related)) {
            Write-Host (" [{0}]" -f $related) -ForegroundColor Gray
        } else {
            # We need that to print a new line
            Write-Host ""
        }
    }
}

New-CommandWrapper -Name Out-Default `
-Begin {
    $notfirst = $false
} `
-Process {
    $regex_opts = ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    $compressed = New-Object System.Text.RegularExpressions.Regex(
        '\.(7z|zip|tar|gz|rar|jar|war)$', $regex_opts)
    $executable = New-Object System.Text.RegularExpressions.Regex(
        '\.(exe|bat|cmd|py|pl|ps1|psm1|psd1|vbs|rb|reg)$', $regex_opts)
    $text_files = New-Object System.Text.RegularExpressions.Regex(
        '\.(txt|cfg|conf|ini|csv|log|xml|yml|json)$', $regex_opts)
    $doc_files = New-Object System.Text.RegularExpressions.Regex(
        '\.(doc|docx|ppt|pptx|xls|xlsx|mdb|mdf|ldf)$', $regex_opts)
    $source_files = New-Object System.Text.RegularExpressions.Regex(
        '\.(java|c|cpp|cs|fs|fsi|fsx|ml|mli)$', $regex_opts)
    $solution_files = New-Object System.Text.RegularExpressions.Regex(
        '\.(sln|csproj|sqlproj|proj|targets)$', $regex_opts)

    if(($_ -is [System.IO.DirectoryInfo]) -or ($_ -is [System.IO.FileInfo]) -or ($_ -is [System.Management.Automation.Internal.AlternateStreamData]))
    {
        if(-not ($notfirst))
        {
           Write-Host
           Write-Host "    Directory: " -noNewLine
           Write-Host " $(Get-Location)`n" -foregroundcolor "Magenta"
           Write-Host "Mode                LastWriteTime     Length Name"
           Write-Host "----                -------------     ------ ----"
           $notfirst=$true
        }

        $rootDirectory = $(Get-Location)
        if ($_ -is [System.IO.DirectoryInfo])
        {
            Write-Color-LS "Magenta" $_ $rootDirectory
        }
        elseif ($compressed.IsMatch($_.Name))
        {
            Write-Color-LS "DarkRed" $_ $rootDirectory
        }
        elseif ($executable.IsMatch($_.Name))
        {
            Write-Color-LS "DarkGreen" $_ $rootDirectory
        }
        elseif ($text_files.IsMatch($_.Name))
        {
            Write-Color-LS "DarkYellow" $_ $rootDirectory
        }
        elseif ($doc_files.IsMatch($_.Name))
        {
            Write-Color-LS "Yellow" $_ $rootDirectory
        }
        elseif ($source_files.IsMatch($_.Name))
        {
            Write-Color-LS "Cyan" $_ $rootDirectory
        }
        elseif ($solution_files.IsMatch($_.Name))
        {
            Write-Color-LS "DarkCyan" $_ $rootDirectory
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
    elseif (($_ -is [System.Collections.Generic.Dictionary`2[System.String,System.Management.Automation.FunctionInfo]]) -or
            ($_ -is [System.Collections.Generic.Dictionary`2[System.String,System.Management.Automation.CommandInfo]]))
    {
        $entries = $_.GetEnumerator()
        $entries | ForEach-Object -Process {
            $key = $_.Key
            $fn = $_.Value

            try {
                $value = Get-Command -Name $key -Module $fn.ModuleName -Syntax -ErrorAction SilentlyContinue
            } catch [System.Management.Automation.PSArgumentOutOfRangeException] {
                $value = $null
                Write-Host "[Cannot parse '$($key.ToString())' of '$($fn.ModuleName)' --- check command definition] " -ForegroundColor Red -NoNewline
            }
            if ($value -eq $null)
            {
                $value = $_.Value.ToString()
                Write-Host ("{0}" -f $value.Trim().Replace("`n`r", "")) -ForegroundColor Yellow
            } elseif ($fn.CommandType -eq [System.Management.Automation.CommandTypes]::Alias) {
                Write-Host ("{0}" -f $fn.DisplayName) -ForegroundColor DarkYellow
            } else {
                Write-Host ("{0}" -f $value.Trim().Replace("`n`r", "")) -ForegroundColor Yellow
            }
        }
        $_ = $null
    }
    elseif ($_ -is [System.Array]) {
        Write-HostCustomized-Dispatcher -Target $_
        $_ = $null
    }
    elseif ($_ -eq $null)
    {
        # Disable the following for the default behavior
        # Write-Host "<null>" -ForegroundColor Red
    }
    elseif ($_.GetType().ImplementedInterfaces.Contains([System.Collections.IDictionary]))
    {
        Write-Host "Key                        " -NoNewLine -ForegroundColor "Magenta"
        Write-Host "  Value"                                -ForegroundColor "DarkGreen"
        Write-Host "-------------------------- --------------------------"
        $entries = $_.GetEnumerator()
        $entries | ForEach-Object -Process {
            $key = $_.Key
            $value = $_.Value
            Write-Host ("{0,-25}" -f $key) -NoNewLine -ForegroundColor "Magenta"
            Write-Host " = " -NoNewLine
            Write-Host ("{0,-25}" -f $value) -ForegroundColor "DarkGreen"
        }
        $_ = $null
    }
    elseif (("System.Security.Cryptography.X509Certificates.X509CertificateContextProperty" -as [type]) -and ($_ -is [System.Security.Cryptography.X509Certificates.X509CertificateContextProperty]))
    {
        if(-not ($notfirst))
        {
           Write-Host
           Write-Host ("{0,-50} {1,-17} {2}" -f "Certificate","Property","Value")
           Write-Host ("{0} {1} {2}" -f [System.String]::new('-', 50),[System.String]::new('-', 17),[System.String]::new('-', 30))
           $notfirst=$true
        }

        $certproperty = [System.Security.Cryptography.X509Certificates.X509CertificateContextProperty]$_
        $certificate = $certproperty.Certificate.Subject.ToString()
        $property = $certproperty.PropertyName
        $value = $certproperty.PropertyValue

        if ($certificate.Length -gt 45) {
            $certificate = "{0}..." -f $certificate.Substring(0, 45)
        }

        if ($value -is [PKI.Structs.Wincrypt+CRYPT_KEY_PROV_INFO]) {
            [PKI.Structs.Wincrypt+CRYPT_KEY_PROV_INFO]$v = $value
            $valuestr = $v.pwszContainerName
        } elseif ($null -ne $value) {
            $valuestr = $value.ToString()
        } else {
            $valuestr = ""
        }

        Write-Host ("{0,-50} [{1,-15}] {2}" -f $certificate,$property,$valuestr)
        $_ = $null
    }
    else
    {
        # Write-Host $_.GetType()
        # Write-Host $_.ToString()
        # $_ = $null
    }
} `
-End {
    # The following results in printing an empty line.
    # If this script is called multiple times, the result will be multiple empty lines to accumulate.
    # This is fine, since the script is called multiple times only during dev.
    write-host ""
}
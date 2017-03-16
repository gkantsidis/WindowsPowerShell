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
            $related = Get-RelativePath -Target $file.Parent.FullName -Base $rootDirectory.ProviderPath
        } elseif ($file -is [System.IO.FileInfo]) {
            $related = Get-RelativePath -Target $file.Directory.FullName -Base $rootDirectory.ProviderPath
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
    elseif (($_ -is [System.Collections.Generic.Dictionary`2[System.String,System.Management.Automation.FunctionInfo]]) -or
            ($_ -is [System.Collections.Generic.Dictionary`2[System.String,System.Management.Automation.CommandInfo]]))
    {
        $entries = $_.GetEnumerator()
        $entries | ForEach-Object -Process {
            $key = $_.Key
            $fn = $_.Value
            
            $value = Get-Command -Name $key -Module $fn.ModuleName -Syntax -ErrorAction SilentlyContinue
            if ($value -eq $null)
            {
                $value = $_.Value.ToString()
                Write-Host ("{0}" -f $value.Trim().Replace("`n`r", "")) -ForegroundColor "DarkGreen"
            } elseif ($fn.CommandType -eq [System.Management.Automation.CommandTypes]::Alias) {
                Write-Host ("{0}" -f $fn.DisplayName) -ForegroundColor "Green"
            } else {                
                Write-Host ("{0}" -f $value.Trim().Replace("`n`r", "")) -ForegroundColor "DarkGreen"
            }
        }
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
        $certproperty = [System.Security.Cryptography.X509Certificates.X509CertificateContextProperty]$_
        $certificate = $certproperty.Certificate.Subject
        $property = $certproperty.PropertyName        
        $value = $certproperty.PropertyValue

        if ($value -is [PKI.Structs.Wincrypt+CRYPT_KEY_PROV_INFO]) {
            [PKI.Structs.Wincrypt+CRYPT_KEY_PROV_INFO]$v = $value
            $valuestr = $v.pwszContainerName
        } elseif ($null -ne $value) {
            $valuestr = $value.ToString()
        } else {
            $valuestr = ""
        }
        
        Write-Host ("{0,-25} [{1,-15}] {2}" -f $certificate,$property,$valuestr)
        $_ = $null
    }
    else 
    {
        # Write-Host $_.ToString()
        # $_ = $null
    }
} `
-End {
    write-host ""
}
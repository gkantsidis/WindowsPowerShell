#Requires -Version 3
#Requires -Modules posh-git


function Set-LocationWithHints {
    [CmdletBinding(DefaultParameterSetName='Path')]
    param(
        [Parameter(Position=0, ParameterSetName='Path', ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string]
        $Path,

        [Parameter(Position=0, ParameterSetName='LiteralPath', ValueFromPipelineByPropertyName=$true)]
        [Alias("PSPath")]
        [string]
        $LiteralPath,

        [switch]
        $ExpandPath,

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [switch]
        $UseTransaction,

        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]
        $UnboundArguments
    )

    Begin
    {
        Write-Verbose -Message "Starting initialization"

        Set-StrictMode -Version Latest
        $realcd = (Get-Alias cd).Definition
        if ([System.String]::IsNullOrWhiteSpace($realcd)) {
            Write-Verbose -Message "Cannot find alias for cd; will use default"
            $realcd = "Set-Location"
        }

        $isAdmin = Test-AdminRights

        $testcmder = Get-Command -Name RenameTab -ErrorAction SilentlyContinue
        if ($null -eq $testcmder) {
            $isCmder = $false
        } else {
            $isCmder = $true
        }

        Write-Verbose -Message "Done with initialization"
    }

    Process
    {
        function DoChangePath($realcd, $Path) {
            switch($realcd)
            {
                'Pscx\Set-LocationEx' {
                    if ($PSCmdlet.ParameterSetName -eq 'Path') {
                        if ($null -eq $UnboundArguments) {
                            Write-Verbose -Message "Changing path with Set-LocationEx and unbound arguments"
                            Set-LocationEx  -Path $Path `
                                            -UnboundArguments $UnboundArguments `
                                            -PassThru:$PassThru.IsPresent `
                                            -UseTransaction:$UseTransaction.IsPresent
                        } else {
                            Write-Verbose -Message "Changing path with Set-LocationEx"
                            Set-LocationEx  -Path $Path `
                                            -PassThru:$PassThru.IsPresent `
                                            -UseTransaction:$UseTransaction.IsPresent
                        }
                    } else {
                        if ($null -eq $UnboundArguments) {
                            Write-Verbose -Message "Changing path with Set-LocationEx, literal path, and unbound arguments"
                            Set-LocationEx  -LiteralPath $Path `
                                            -UnboundArguments $UnboundArguments `
                                            -PassThru:$PassThru.IsPresent `
                                            -UseTransaction:$UseTransaction.IsPresent
                        } else {
                            Write-Verbose -Message "Changing path with Set-LocationEx and literal path"
                            Set-LocationEx  -LiteralPath $Path `
                                            -PassThru:$PassThru.IsPresent `
                                            -UseTransaction:$UseTransaction.IsPresent
                        }
                    }
                }
                'Set-Location' {
                    if ($PSCmdlet.ParameterSetName -eq 'Path') {
                        Write-Verbose -Message "Changing path with Set-Location"
                        Set-Location    -Path $Path `
                                        -PassThru:$PassThru.IsPresent `
                                        -UseTransaction:$UseTransaction.IsPresent
                    } else {
                        Write-Verbose -Message "Changing path with Set-Location and literal path"
                        Set-Location    -LiteralPath $Path `
                                        -PassThru:$PassThru.IsPresent `
                                        -UseTransaction:$UseTransaction.IsPresent
                    }
                }
                'cdX' {
                    $cdxcommand = (get-command cdx)
                    if ($cdxcommand.Parameters.ContainsKey("UseTransaction")) {
                        if ($PSCmdlet.ParameterSetName -eq 'Path') {
                            Write-Verbose -Message "Changing path with Set-Location"
                            cdX -Path $Path `
                                -PassThru:$PassThru.IsPresent `
                                -UseTransaction:$UseTransaction.IsPresent
                        } else {
                            Write-Verbose -Message "Changing path with Set-Location and literal path"
                            cdX -LiteralPath $Path `
                                -PassThru:$PassThru.IsPresent `
                                -UseTransaction:$UseTransaction.IsPresent
                        }
                    } else {
                        if ($PSCmdlet.ParameterSetName -eq 'Path') {
                            Write-Verbose -Message "Changing path with Set-Location"
                            cdX -Path $Path `
                                -PassThru:$PassThru.IsPresent
                        } else {
                            Write-Verbose -Message "Changing path with Set-Location and literal path"
                            cdX -LiteralPath $Path `
                                -PassThru:$PassThru.IsPresent
                        }
                    }
                }
            }
        }

        DoChangePath $realcd $Path

        if ($ExpandPath) {
            $realpath = $pwd.ProviderPath
            DoChangePath $realcd $realpath

            [string[]]$components = @()
            $current = Get-Item -Path .
            $stopsearch = $false
            do {
                Write-Debug -Message "Examining $current"
                if ([System.String]::Equals($current.LinkType, "Junction", [System.StringComparison]::InvariantCultureIgnoreCase)) {
                    Write-Debug -Message "Detected that $current is junction"
                    $realpath = Select-Object -InputObject $current -ExpandProperty Target
                    DoChangePath $realcd $realpath
                    $current = Get-Item -Path .
                } else {
                    $thispath = Split-Path -Path $current -Leaf
                    $components += $thispath
                    $parent = Split-Path -Path $current -Parent
                    if ([System.String]::IsNullOrWhiteSpace($parent)) {
                        $stopsearch = $true
                        $current = $null
                    } else {
                        $current = Get-Item -Path $parent
                    }
                }
            } until ($stopsearch -or ($null -eq $current))

            Write-Debug -Message "Components: $components"
            $components = $components.Reverse()
            Write-Debug -Message "Components in order: $components"
            $realpath = [System.IO.Path]::Combine($components)
            Write-Verbose -Message "Switching to $realpath"
            DoChangePath $realcd $realpath

        }

        $mpwd = Get-Location
        $pp = $mpwd.ProviderPath
        if ($pp.StartsWith("\\")) {
            $endhost = $pp.IndexOf('\', 2)
            $host_name = $pp.Substring(2, $endhost-2)
        } else {
            $host_name = $null
        }

        $leaf = Split-Path $mpwd.ProviderPath -Leaf

        # The command Get-GitStatus may return a non-null object even if the path is not part of a git repository.
        # For example, it is possible to put .git in the root (e.g. C:\.git) to register hooks.
        $git = Get-GitStatus
        if ( ($null -eq $git) -and (Test-Path -Path (Join-Path -Path $git.GitDir -ChildPath "config")) ) {
            $gitroot = Split-Path (Split-Path $git.GitDir -Parent) -Leaf
        } else {
            $gitroot = $null
        }

        $header = ""
        if ($isCmder) {
            if ($isAdmin) { $header += "*"}
            if ($null -eq $host_name) { $header += "@"}
            if ($null -eq $gitroot) { $header += "$gitroot" } else { $header += "$leaf"}

            RenameTab $header
        } else {
            if ($isAdmin) { $header += "[Admin] "}
            if ($null -eq $host_name) { $header += "\\$host_name "}
            if ($null -eq $gitroot) { $header += "$gitroot " }
            $header += "$leaf"

            Set-Title -Message $header
        }
    }
}

function zz ($path) { Set-LocationWithHints -ExpandPath -Path $path }
Set-Alias -Name cdz -Value Set-LocationWithHints
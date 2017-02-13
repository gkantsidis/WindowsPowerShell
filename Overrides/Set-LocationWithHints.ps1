#Requires -Version 3
#Requires -Modules posh-git
#Requires -Modules xUtility

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

        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]
        $UnboundArguments,

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [switch]
        $UseTransaction
    )

    Begin
    {
        Set-StrictMode -Version Latest
        $realcd = (Get-Alias cd).ResolvedCommandName

        $isAdmin = Test-AdminRights

        $testcmder = Get-Command -Name RenameTab -ErrorAction SilentlyContinue
        if ($testcmder -eq $null) {
            $isCmder = $false
        } else {
            $isCmder = $true
        }
    }

    Process
    {
        switch($realcd)
        {
            'Set-LocationEx' {
                if ($PSCmdlet.ParameterSetName -eq 'Path') {
                    if ($UnboundArguments -ne $null) {
                        Set-LocationEx  -Path $Path `
                                        -UnboundArguments $UnboundArguments `
                                        -PassThru:$PassThru.IsPresent `
                                        -UseTransaction:$UseTransaction.IsPresent
                    } else {
                        Set-LocationEx  -Path $Path `
                                        -PassThru:$PassThru.IsPresent `
                                        -UseTransaction:$UseTransaction.IsPresent                        
                    }
                } else {
                    if ($UnboundArguments -ne $null) {
                        Set-LocationEx  -LiteralPath $Path `
                                        -UnboundArguments $UnboundArguments `
                                        -PassThru:$PassThru.IsPresent `
                                        -UseTransaction:$UseTransaction.IsPresent
                    } else {
                        Set-LocationEx  -LiteralPath $Path `
                                        -PassThru:$PassThru.IsPresent `
                                        -UseTransaction:$UseTransaction.IsPresent                        
                    }                    
                }
            }
            'Set-Location' {
                if ($PSCmdlet.ParameterSetName -eq 'Path') {
                    Set-Location    -Path $Path `
                                    -PassThru:$PassThru.IsPresent `
                                    -UseTransaction:$UseTransaction.IsPresent
                } else {
                    Set-Location    -LiteralPath $Path `
                                    -PassThru:$PassThru.IsPresent `
                                    -UseTransaction:$UseTransaction.IsPresent
                }
            }
        }

        $pwd = Get-Location
        $pp = $pwd.ProviderPath
        if ($pp.StartsWith("\\")) {
            $endhost = $pp.IndexOf('\', 2)
            $host_name = $pp.Substring(2, $endhost-2)
        } else {
            $host_name = $null
        }

        $leaf = Split-Path $pwd.ProviderPath -Leaf

        $git = Get-GitStatus
        if ($git -ne $null) {
            $gitroot = Split-Path (Split-Path (Get-GitStatus).GitDir -Parent) -Leaf
        } else {
            $gitroot = $null
        }

        $header = ""
        if ($isCmder) {
            if ($isAdmin) { $header += "*"}
            if ($host_name -ne $null) { $header += "@"}
            if ($gitroot -ne $null) { $header += "$gitroot" } else { $header += "$leaf"}

            RenameTab $header
        } else {
            if ($isAdmin) { $header += "[Admin] "}
            if ($host_name -ne $null) { $header += "\\$host_name "}
            if ($gitroot -ne $null) { $header += "$gitroot " }
            $header += "$leaf"

            Set-Title -Message $header
        }            
    }
}

Set-Alias -Name cdx -Value Set-LocationWithHints
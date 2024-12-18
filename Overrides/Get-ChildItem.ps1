function Get-ChildItem {

[CmdletBinding(DefaultParameterSetName='Items', SupportsTransactions=$true, HelpUri='http://go.microsoft.com/fwlink/?LinkID=113308')]
param(
    [Parameter(ParameterSetName='Items', Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [string[]]
    ${Path},

    [Parameter(ParameterSetName='LiteralItems', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
    [Alias('PSPath')]
    [string[]]
    ${LiteralPath},

    [Parameter(Position=1)]
    [string]
    ${Filter},

    [string[]]
    ${Include},

    [string[]]
    ${Exclude},

    [Alias('s')]
    [switch]
    ${Recurse},

    [uint32]
    ${Depth},

    [switch]
    ${Force},

    [ValidateSet("All", "ASM", "C", "C99", "CS", "FS", "Java", "Julia", "ML", "Perl", "Python", "PS", "TeX", "Libraries")]
    [System.String[]]
    ${SourceCode},


    [switch]
    ${Name})


dynamicparam
{
    try {
        $targetCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Management\Get-ChildItem', [System.Management.Automation.CommandTypes]::Cmdlet, $PSBoundParameters)
        if ($targetCmd.Parameters) {
            $dynamicParams = @($targetCmd.Parameters.GetEnumerator() | Microsoft.PowerShell.Core\Where-Object { $_.Value.IsDynamic })
            if ($dynamicParams.Length -gt 0)
            {
                $paramDictionary = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
                foreach ($param in $dynamicParams)
                {
                    $param = $param.Value

                    if(-not $MyInvocation.MyCommand.Parameters.ContainsKey($param.Name))
                    {
                        $dynParam = [Management.Automation.RuntimeDefinedParameter]::new($param.Name, $param.ParameterType, $param.Attributes)
                        $paramDictionary.Add($param.Name, $dynParam)
                    }
                }
                return $paramDictionary
            }
        }
    } catch {
        throw
    }
}

begin
{
    try {
        $outBuffer = $null
        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Management\Get-ChildItem', [System.Management.Automation.CommandTypes]::Cmdlet)

        [string[]]$sourceCodeSelection = @()
        if ($PSBoundParameters.TryGetValue('SourceCode', [ref]$sourceCodeSelection)) {
            $filterParameter = $null
            if ($PSBoundParameters.TryGetValue('Include', [ref]$filterParameter)) {
                $null = $PSBoundParameters.Remove(‘Include’)
            } else {
                $filterParameter = @()
            }
            $null = $PSBoundParameters.Remove(‘SourceCode’)

            if ($SourceCode.Contains("ASM") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.asm", "*.S")
            }
            if ($SourceCode.Contains("C") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.cpp", "*.hpp")
            }
            if ($SourceCode.Contains("C") -or $SourceCode.Contains("C99") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.c", "*.h")
            }
            if ($SourceCode.Contains("CS") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.cs")
            }
            if ($SourceCode.Contains("FS") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.fs", "*.fsi", "fsx", "fsl", "fsy")
            }
            if ($SourceCode.Contains("Java") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.java")
            }
            if ($SourceCode.Contains("Julia") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.jl", "Project.toml", "Manifest.toml")
            }
            if ($SourceCode.Contains("ML") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.ml", "*.mli", "*.mll", "*.mly")
            }
            if ($SourceCode.Contains("Perl") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.pl")
            }
            if ($SourceCode.Contains("PS") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.ps1", "*.psd1", "*.psm1")
            }
            if ($SourceCode.Contains("Python") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.py")
            }
            if ($SourceCode.Contains("TeX") -or $SourceCode.Contains("All")) {
                $filterParameter += @("*.tex", "*.bib", "*.sty")
		}

            Write-Verbose -Message "File filter: $filterParameter"
            $null = $PSBoundParameters.Add('Include', $filterParameter)

            if ((-not $PSBoundParameters.ContainsKey("Path")) -and (-not $PSBoundParameters.ContainsKey("Recurse"))) {
                $null = $PSBoundParameters.Add('Path', "*")
            }
        }
        $scriptCmd = {& $wrappedCmd @PSBoundParameters }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    } catch {
        throw
    }
}

process
{
    try {
        $steppablePipeline.Process($_)
    } catch {
        throw
    }
}

end
{
    try {
        $steppablePipeline.End()
    } catch {
        throw
    }
}
<#

.ForwardHelpTargetName Microsoft.PowerShell.Management\Get-ChildItem
.ForwardHelpCategory Cmdlet

#>

}

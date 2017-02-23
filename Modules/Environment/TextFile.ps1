
<#PSScriptInfo

.VERSION 1.0

.GUID 91396db9-1937-4e08-b6c4-df3bf423eff6

.AUTHOR Christos Gkantsidis

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
 Helpers for text files 

#>
function Get-FileHead {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipeline=$True, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path,

        [int]
        $Count = 20
    )

    BEGIN {
    }
    PROCESS {
        if ($Path -ne $null) {
            $hasMultipleInputs = $Path.Length -gt 1
        } else {
            $hadMultipleInput = $false
        }
        
        foreach ($file in $Path) {
            if ($hasMultipleInputs) {
                Write-Verbose -Message "File: $file"
            }

            Get-Content -Path $file -TotalCount $Count
        }
    }
    END {
    }
}

Set-Alias -Name head -Value 'Get-FileHead'


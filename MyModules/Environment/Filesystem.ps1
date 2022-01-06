
<#PSScriptInfo

.VERSION 1.0

.GUID 3cc25338-f06c-49ee-b490-549c1654a54e

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
 Compares two directories and returns their differences

#>
function Compare-Directories {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ReferenceDirectory,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TargetDirectory,

        [parameter(Mandatory=$false)]
        [string[]]
        $Exclude = $null
    )
    
    Add-Type -AssemblyName System.Core

    if (-not (Test-Path -Path $ReferenceDirectory -PathType Container)) {
        $directoryError = New-Object -TypeName System.IO.DirectoryNotFoundException -ArgumentList "Invalid reference directory: $ReferenceDirectory"
        throw $directoryError
    }
    if (-not (Test-Path -Path $TargetDirectory -PathType Container)) {
        $directoryError = New-Object -TypeName System.IO.DirectoryNotFoundException -ArgumentList "Invalid target directory: $TargetDirectory"
        throw $directoryError
    }

    $referenceBaseDir = Get-Item -Path $ReferenceDirectory
    $targetBaseDir = Get-Item -Path $TargetDirectory

    $referenceSet = New-Object -TypeName 'System.Collections.Generic.HashSet[string]'
    $targetSet = New-Object -TypeName 'System.Collections.Generic.HashSet[string]'

    Get-ChildItem -Path $ReferenceDirectory -Recurse -Exclude $Exclude | `
    ForEach-Object -Process {
        $file = $_.FullName.Replace($referenceBaseDir.FullName, "").Substring(1)
        $ignore = $referenceSet.Add($file)
    }

    Get-ChildItem -Path $TargetDirectory -Recurse -Exclude $Exclude | `
    ForEach-Object -Process {
        $file = $_.FullName.Replace($targetBaseDir.FullName, "").Substring(1)
        $ignore = $targetSet.Add($file)
    }
    
    Write-Verbose -Message "Computing directory differences"
    $added = [System.Linq.Enumerable]::Except($referenceSet, $targetSet)
    $removed = [System.Linq.Enumerable]::Except($targetSet, $referenceSet)
    $common = [System.Linq.Enumerable]::Intersect($referenceSet, $targetSet)

    Write-Verbose -Message "Computing file differences (slow ...)"
    
    $modified = $common | ForEach-Object `
        -Begin {
            $i = 0
            $totalFilesToCompare =  @($common).Length
        } `
        -Process {
            $file = $_

            $progress = (100 * $i) / $totalFilesToCompare
            $i++
            Write-Progress -Activity "Comparing files" -Status "File $i / $totalFilesToCompare" -PercentComplete $progress

            $referenceFile = Join-Path -Path $referenceBaseDir -ChildPath $file
            $targetFile = Join-Path -Path $targetBaseDir -ChildPath $file

            Write-Verbose -Message "Comparing $referenceFile to $targetFile"

            if ((Test-Path -Path $referenceFile -PathType Container) -and (Test-Path -Path $targetFile -PathType Container)) {
                # Directories --- ignore
            } else {
                # Comparing files

                $rf = Get-Item -Path $referenceFile
                $tf = Get-Item -Path $targetFile

                if ($rf.Length -ne $tf.Length) {
                    Write-Verbose -Message "File  sizes differ"
                    $file
                } else {
                    $referenceHash = Get-FileHash -Path $referenceFile
                    $targetHash = Get-FileHash -Path $targetFile

                    if ($referenceHash.Hash -ne $targetHash.Hash) {
                        Write-Verbose -Message "File hashes differ"
                        $file
                    }
                }
            }
        }

    [PSCustomObject] @{
        Added = $added
        Removed = $removed
        Modified = $modified
        ReferenceDirectory = $referenceBaseDir
        TargetDirectory = $targetBaseDir
    }
}




<#PSScriptInfo

.VERSION 1.0

.GUID ad9d9052-dd2e-42ef-8b4d-4119a3e62cbd

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
 Cleanups the installed packages 

#>
[CmdletBinding(SupportsShouldProcess=$true)] 
Param()

function UninstallModule {
    [CmdletBinding(SupportsShouldProcess=$true)] 
    Param(
        [string]
        $Name,

        $Version
    )

    Write-Verbose -Message "Uninstalling $name of $Version"   
    Uninstall-Module -Name $name -RequiredVersion $Version -ErrorAction SilentlyContinue
    $oldversion = Get-Module $Name -ListAvailable | Where-Object -Property Version -EQ -Value $Version
    if ($oldversion) {
        $path = Split-Path -Path $oldversion.Path -Parent
        Write-Verbose -Message "Failed to uninstall module $name as a package; will try to remove directory $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -Path $path) {
            Write-Error -Message "Failed to uninstall module $name by removing directory $path; please uninstall manually"
        }
    }
}

$packages = Get-Module -ListAvailable

$packages | ForEach-Object -Begin {
    $prevName = $null
    $newestVersion = $null
    $prevType = $null
} -Process {
    $name = $_.Name
    $version = $_.Version
    $type = $_.ModuleType

    Write-Debug -Message "Found $name with version $version of type $type"

    if (($null -eq $prevName) -or ($name -ne $prevName)) {
        # Do nothing; pick up the new info and continue below
        $prevName = $name
        $prevType = $type
        $newestVersion = $version
#    } elseif ($prevType -ne $type) {
#        Write-Verbose "Detected different types for module $name; previous is $prevType with $newestVersion; current is $type with $version"
    } elseif ($newestVersion -lt $version) {
        Write-Verbose "Detected old version of module $name : old=$newestVersion, current=$version; Removing $newestVersion ..."
        UninstallModule -Name $name -Version $newestVersion
        $newestVersion = $verson
    } elseif ($version -lt $newestVersion) {
        Write-Verbose "Detected old version of module $name : old=$version, current=$newestVersion; Removing $version ..."
        UninstallModule -Name $name -Version $version
    } else {
        Write-Error -Message "The module $name appears to have two installations for the same version $version"
    }
}



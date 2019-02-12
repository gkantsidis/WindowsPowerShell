#
# Helper methods for dealing with PowerShell objects.
#

Function Join-Objects {
<#
    .SYNOPSIS
    Combine two PowerShell Objects into one.

    .DESCRIPTION
    will combine two custom powershell objects in order to make one. This can be helpfull to add information to an already existing object. (this might make sence in all the cases through).


    .EXAMPLE

    Combine objects allow you to combine two seperate custom objects together in one.

    $Object1 = [PsCustomObject]@{"UserName"=$UserName;"FullName" = $FullName;"UPN"=$UPN}
    $Object2 = [PsCustomObject]@{"VorName"= $Vorname;"NachName" = $NachName}

    Join-Object -Object1 $Object1 -Object2 $Object2

    Name                           Value
    ----                           -----
    UserName                       Vangust1
    FullName                       Stephane van Gulick
    UPN                            @PowerShellDistrict.com
    VorName                        Stephane
    NachName                       Van Gulick

    .EXAMPLE

    It is also possible to combine system objects (Which could not make sence sometimes though!).

    $User = Get-ADUser -identity vanGulick
    $Bios = Get-wmiObject -class win32_bios

    Join-Objects -Object1 $bios -Object2 $User


    .NOTES
    -Author: Stephane van Gulick
    -Twitter : stephanevg
    -CreationDate: 10/28/2014
    -LastModifiedDate: 10/28/2014
    -Version: 1.0
    -History:

.LINK

http://www.powershellDistrict.com

#>


    Param (
        [Parameter(mandatory=$true)]$Object1,
        [Parameter(mandatory=$true)]$Object2
    )

    # The code below is a slight variation of the code from the website.

    $arguments = @{}

    foreach ($Property in $Object1.psobject.Properties) {
        $arguments.Add($Property.Name, $Property.value)

    }

    foreach ($Property in $Object2.psobject.Properties) {
        if ($arguments.ContainsKey($Property.Name)) {
            Write-Warning -Message "Property '$($Property.Name)' is common to both objects; ignoring the second instance."
        } else {
            $arguments.Add($Property.Name, $Property.value)
        }
    }


    $Object3 = [PSCustomObject]$arguments


    return $Object3
}
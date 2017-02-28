
<#PSScriptInfo

.VERSION 1.0

.GUID 6cceb503-44fc-4afc-8361-7f7d9dda6f7a

.AUTHOR Christos

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

[datetime] $script:unix_epoch_origin = '1970-01-01 00:00:00'

<# 

.DESCRIPTION 
 Convert from Unix timestamps

#>
function ConvertFrom-UnixDate {
    [CmdletBinding()]
    Param(
        [double]
        $UnixEpoch
    )

    return ($script:unix_epoch_origin.AddSeconds($UnixEpoch))
}

function ConvertTo-UnixDate {
    [CmdletBinding()]
    Param(
        [datetime]
        $Timestamp
    )
    
    return ($Timestamp.Subtract($script:unix_epoch_origin).TotalSeconds)
}
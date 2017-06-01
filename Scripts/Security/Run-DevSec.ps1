[CmdletBinding()]
param(

)

if (-not (Get-Command -Name inspec -ErrorAction SilentlyContinue)) {
    Write-Error -Message "Consider installing inspec, e.g. cinst -y inspec"
    return
}

inspec exec https://github.com/dev-sec/windows-baseline
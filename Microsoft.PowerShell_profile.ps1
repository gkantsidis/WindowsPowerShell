#
# Add our module directory to the path
# (Not all modules will work in all editions of PS)
#

$user_modules = Join-Path -Path $PSScriptRoot -ChildPath MyModules
if ($null -ne $Env:PSModulePath) {
    $modulePaths = $Env:PSModulePath.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    if ($modulePaths -notcontains $user_modules) {
        $Env:PSModulePath += ";$user_modules"
    }
} else {
    Write-Warning -Message "Env:PSModulePath is empty!"
    $Env:PSModulePath = $user_modules
}

$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Push-Location $private:PowerShellProfileDirectory

return

$full_experience = Join-Path -Path $PSScriptRoot -ChildPath "full-experience.ps1"
if (Test-Path -Path $full_experience) {
    . $full_experience
} else {
    Write-Warning -Message "No full experience available"
}

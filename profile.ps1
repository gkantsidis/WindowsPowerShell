# Make sure that %HOMEDRIVE%%HOMEPATH%\Documents\WindowsPowerShell or destination directory is in PSModulePath

$private:PowerShellProfileDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Push-Location $private:PowerShellProfileDirectory

if (Test-Path -Path profile_local.ps1 -PathType Leaf) {
    Write-Verbose -Message "Calling profile_local.ps1"
    . .\profile_local.ps1
}

If (Test-Path "C:\Program Files\openssh-win64\Set-SSHDEfaultShell.ps1") {
    {& "C:\Program Files\openssh-win64\Set-SSHDEfaultShell.ps1"}
}

Pop-Location

# Add modules for PowerShellEditorServices
$PSEditorServicesPath = Join-Path -Path $PSScriptRoot -ChildPath "Modules-VSCode" | `
                        Join-Path -ChildPath "PowerShellEditorServices" |`
                        Join-Path -ChildPath "module"
$userPsPath = [Environment]::GetEnvironmentVariable("PSModulePath", [EnvironmentVariableTarget]::User)
$machinePsPath = [Environment]::GetEnvironmentVariable("PSModulePath", [EnvironmentVariableTarget]::Machine)

if ((Test-Path -Path $PSEditorServicesPath) -and `
    (-not $Env:PSModulePath.Contains($PSEditorServicesPath)) -and `
    (($userPsPath -eq $null) -or (-not $userPsPath.Contains($PSEditorServicesPath))) -and `
    (($machinePsPath -eq $null) -or (-not $machinePsPath.Contains($PSEditorServicesPath)))
    )
{
    $current = [Environment]::GetEnvironmentVariable("PSModulePath", [EnvironmentVariableTarget]::User)
    if ([string]::IsNullOrWhiteSpace($current)) {
        [Environment]::SetEnvironmentVariable("PSModulePath", $PSEditorServicesPath, [EnvironmentVariableTarget]::User)
    } else {
        $newpath = "{0};{1}" -f $current,$PSEditorServicesPath
        [Environment]::SetEnvironmentVariable("PSModulePath", $newpath, [EnvironmentVariableTarget]::User)
    }
    $Env:PSModulePath += ";$PSEditorServicesPath"
}

# General alias
function Get-GitLog { git log --oneline --all --graph --decorate $args }
Set-alias gitlog Get-GitLog

function fzf() {
  try {
    $fzf = Get-Command -CommandType Application fzf -ErrorAction Stop
    if (Test-Path Env:\TERM) {
      $saveTERM = $Env:TERM
      $Env:TERM = ""
    }
    & $fzf @Args
  }
  finally {
    if (Test-Path Variable:\saveTERM) {
      $Env:TERM = $saveTERM
    }
  }
}

# Shortcuts

New-PSDrive -Name me -PSProvider FileSystem -Root ([Environment]::GetFolderPath("User"))
New-PSDrive -Name ps -PSProvider FileSystem -Root $PSScriptRoot

. C:\Users\chrisgk.EUROPE\AppData\Roaming\dystroy\broot\config\launcher\powershell\br.ps1

#region mamba initialize
# !! Contents within this block are managed by 'mamba shell init' !!
$Env:MAMBA_ROOT_PREFIX = "$Env:HOME\micromamba"
$Env:MAMBA_EXE = "$Env:HOME\AppData\Local\micromamba\micromamba.exe"
(& $Env:MAMBA_EXE 'shell' 'hook' -s 'powershell' -p $Env:MAMBA_ROOT_PREFIX) | Out-String | Invoke-Expression
#endregion

#Requires -Module xUtility

<#
 # Cmdlets for simplifying the management of Python environments.
 #
 # In summary, the approach is as follows:
 # - Install a basic environment with the "Install-PyBase" command.
 #   This installs modules for managing virtual environments, and for
 #   checking code quality. The latter are necessary because various tools
 #   (e.g. Visual Studio Code) do not necessarily start from within an
 #   environment. Other modules that are also required by such tools
 #   should also be installed in this system-wide python.
 #   The installation takes place in elevated mode using the chocolatey installer.
 #
 # - Set up a permanent link for python in %SYSTEMDRIVE%\tools\Stable\Python,
 #   (typically c:\tools\Stable\Python), and change the %PATH% variable to point to that.
 #>

#
# Collections of modules
#

[string[]]$virtual_environment_modules = Get-Content -LiteralPath (
    Join-Path -Path $PSScriptRoot -ChildPath "python-virtual-envs.txt")
     
[string[]]$code_quality_modules = Get-Content -LiteralPath (
    Join-Path -Path $PSScriptRoot -ChildPath "python-code-quality.txt")

[string[]]$code_environment_modules = Get-Content -LiteralPath (
    Join-Path -Path $PSScriptRoot -ChildPath "python-env-extra.txt")

$python_user_envs = Join-Path -Path $Env:USERPROFILE -ChildPath "Envs"

#
# Helper scripts
#

function Test-Verbose {
    [CmdletBinding()]
    param()
    [bool](Write-Verbose ([String]::Empty) 4>&1)
}

function InstallPip {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [ValidateNotNullOrEmpty()]
        [string[]]$Modules,

        [ValidateNotNullOrEmpty()]
        [string]$Description
    )

    if (Test-Verbose) {
        $install_arguments = @("install", "--verbose") + $Modules
    } else {
        $install_arguments = @("install") + $Modules
    }

    if ($PSCmdlet.ShouldProcess("Python", $Description)) {
        if (-not (Test-AdminRights)) {
            Start-Process pip -Verb runas -ArgumentList $install_arguments -Wait
        } else {
            if (Test-Verbose) {
                pip install --verbose $Modules
            } else {
                pip install $Modules   
            }
        }
    }
}
function Test-Python ([string]$python = $null, [string]$pip = $null) {
    if ([String]::IsNullOrWhiteSpace($python)) {
        $python = "python"
    }
    $pythonExe = Get-Command -Name $python -ErrorAction SilentlyContinue

    if (-not $pythonExe) {
        return $false
    }

    if ([String]::IsNullOrWhiteSpace($pip)) {
        $python_root = Split-Path -Parent $pythonExe.Path
        $pip = Join-Path -Path $python_root -ChildPath "Scripts" | `
               Join-Path -ChildPath "pip.exe"         
    }

    $pipExe = Get-Command -Name $pip -ErrorAction SilentlyContinue
    return $pipExe -ne $null
}

#
# Exported cmdlets
#
function Install-PythonBase {
    <#
    .SYNOPSIS
    Installs a basic python environment.
    
    .DESCRIPTION
    Install python, if not already installed, and make sure
    that the modules required for managing virtual environment,
    as well as other interesting modules (e.g. pep8 and others
    for checking code quality) are installed.
    
    .PARAMETER VersionMajor
    Minimum major version of python expected
    
    .PARAMETER VersionMinor
    Minimum minor version of python expected
    
    .EXAMPLE
    PS> Install-PythonBase
    
    .NOTES
    TODO: Change system path.
    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [int]$VersionMajor = 3,
        [int]$VersionMinor = 6,

        [ValidateNotNullOrEmpty()]
        [string]$StableLocation = (Join-Path -Path $Env:SystemDrive -ChildPath tools | Join-Path -ChildPath Stable | Join-Path -ChildPath python)
    )

    if (-not (Test-Python)) {
        # Python does not exist

        if ($PSCmdlet.ShouldProcess("Python", "Install")) {
            if (Test-AdminRights) {            
                cinst -y python                
            } else {
                Start-Process cinst -Verb runas -ArgumentList "-y","python" -Wait
            }
            refreshenv
        }
    }

    if (-not (Test-Python)) {
        Write-Error -Message "Something is wrong with python's installation (python or pip not found); aborting..."
        return
    }

    $requiredVersion = [Version]::new($VersionMajor, $VersionMinor)
    $python = Get-Command -Name python
    if ($python.Version.CompareTo($requiredVersion) -eq -1) {
        Write-Warning -Message "Python's existing version older than $requiredVersion; consider upgrading"
    }

    InstallPip -Modules $virtual_environment_modules -Description "Install modules to help with virtual environments"
    InstallPip -Modules $code_quality_modules -Description "Install code quality modules"

    if (-not (Test-Path -Path $StableLocation)) {
        Write-Verbose -Message "Creating stable link"
        $pythonDirectory = Split-Path -Parent $python.Path
        if ($pythonDirectory.EndsWith("Scripts", [System.StringComparison]::InvariantCultureIgnoreCase)) {
            $pythonDirectory = Split-Path -Parent $pythonDirectory
        }
        New-Item -ItemType Junction -Path $StableLocation -Value $pythonDirectory

        Write-Host -ForegroundColor Yellow -Object "Redirect PATH to point to $StableLocation instead of $pythonDirectory"
    }
}

function New-PythonVirtualEnvironment {
    <#
    .SYNOPSIS
    Initializes a python virtual environment
    
    .DESCRIPTION
    Initializes a python virtual environment. This is a wrapper
    around the virtualenv and virtualenvwrapper-win modules.
    It also installs a few basic packages.
    
    .PARAMETER Name
    Name of the virtual environment.
    
    .PARAMETER Local
    If present the environment will be local to current directory.
    Otherwise, it is a user-specific environment.
    
    .PARAMETER Conda
    If present, it installs the conda environment.
    
    .PARAMETER NoExtraModules
    If present, no other modules will be installed in new enviroment.

    .PARAMETER DoNotSwitchEnvironment
    After installation, deactivate the newly created virtual environment.
    
    .PARAMETER Python
    Path to python executable that will be the base for the installation.
    Observe, that if "-Conda" is specified, then this binary may be replaced.
    
    .EXAMPLE
    PS> New-PythonVirtualEnvironment -Name minimal

    .EXAMPLE
    PS> New-PythonVirtualEnvironment -Name .python -Local
    
    .NOTES
    TODO: Pass extra parameters
    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$True,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [switch]$Local,        
        [switch]$Conda,
        [switch]$NoExtraModules,
        [switch]$DoNotSwitchEnvironment,

        [string]$Python = $null
    )

    if (-not (Test-Python -python $Python)) {
        Write-Error -Message "Something is wrong with python's installation (python or pip not found); aborting..."
        return
    }

    if ($Local) {
        $target_profile = Join-Path -Path $pwd.ProviderPath -ChildPath $Name
    } else {
        $target_profile = Join-Path -Path $python_user_envs -ChildPath $Name
    }

    if (Test-Path $target_profile) {
        Write-Error -Message "Virtual env with name '$Name' cannot be created in '$target_profile' (directory already exists)"
        return
    }

    [string[]]$arguments = @()    
    if (-not [String]::IsNullOrWhiteSpace($Python)) {
        $arguments += ("--python={0}" -f $Python)
    }
    if (Test-Verbose) {
        $arguments += "--verbose"
    }
    $arguments += $Name

    if ($PSCmdlet.ShouldProcess("Python", "Create virtual environment with arguments: $arguments")) {
        if ($Local) {
            virtualenv @arguments
            & ".\$Name\Scripts\activate.ps1"
        } else {
            mkvirtualenv @arguments
            # workon $Name
            & "$target_profile\Scripts\activate.ps1"
        }
    }

    if (Test-Verbose) {
        [string[]]$pip_arguments = @("install", "--verbose")
    } else {
        [string[]]$pip_arguments = @("install")
    }

    if ((-not $NoExtraModules) -and $PSCmdlet.ShouldProcess("Python", ("Install code quality tools: {0}" -f $code_quality_modules))) {
        [string[]]$pip_arguments_here = $pip_arguments + $code_quality_modules + $code_environment_modules
        pip @pip_arguments_here
    }

    if ($Conda) {
        # Install Conda distribution
    }

    if($DoNotSwitchEnvironment) {
        if ($PSCmdlet.ShouldProcess("Python", "Switching back to existing environment")) {
            deactivate
        }
    }
}

Export-ModuleMember -Function Install-PythonBase,New-PythonVirtualEnvironment
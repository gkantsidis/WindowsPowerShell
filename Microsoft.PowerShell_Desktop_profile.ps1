#
# Initialization
#

Import-Module Environment

#
# Checking for external modules
# These are the external modules that we would like to have installed in the system
#
Start-Timing

$modulesToCheck = (
    'PowerShellGet',
    'PSReadLine',
    'GuiCompletion',
    'pscx',
    'PowerShellCookbook',
    'posh-git',
    'posh-with',
    'SnippetPx',
    'TypePx',
    'VSSetup',
    'xUtility',
    'Editors',
    'z'
)

# Measure performance with:
# $modulesToCheck |% {  $t = Measure-Command { Import-Module $_ }; "{0} : {1}" -f $_,$t.Milliseconds }

if ((Get-Random -Maximum 100) -lt 5) {
    Get-ModuleInstall -ModuleName $modulesToCheck -ErrorAction SilentlyContinue
} else {
    Import-Module -Name $modulesToCheck -ErrorAction SilentlyContinue
}

Stop-Timing -Description "Checking for external modules"

Start-Timing

$extraModulesToImport = (
    "Pester",
    # "PowerShellArsenal",
    "TypePx",
    "$PSScriptRoot\Source\PSPKI\PSPKI"
)
$modulesToImport = $modulesToCheck + $extraModulesToImport
Import-Module -Name $modulesToImport -ErrorAction SilentlyContinue

Stop-Timing -Description "Importing modules"

# The other modules are local (i.e. in the repo or in submodules):
# - Editors
# - Pester
# - IsePester
# - PowerShellArsenal
# - Posh-VsVars (not really a module)

#
# Build-in modules and initialization
#
if (Get-Module -Name PSReadLine) {
    . $PSScriptRoot\profile_readline.ps1
} else {
    Write-Warning -Message "Consider installing PSReadLine module"
}

if (Get-Module -Name GuiCompletion) {
    Install-GuiCompletion -Key Tab
    # The alternative is to use the default ctl-space
    # Install-GuiCompletion
}

#
# Third party installable modules
#

Start-Timing
if (-not (Get-Module -Name pscx -ListAvailable)) {
    Write-Warning -Message "Consider installing pscx"
}
if (-not (Get-Module -Name PowerShellCookbook -ListAvailable)) {
    Write-Warning -Message "Consider installing PowerShellCookbook"
}
Stop-Timing -Description "Third party installable modules"

#
# Third party modules with special initialization
#

# Module: posh-git
Start-Timing

# Import the posh-git module.

$poshGitModule = Get-Module posh-git -ListAvailable
if (-not $poshGitModule) {
    Write-Warning "Consider installing posh-git module (as admin): Install-Module -Name posh-git -Force -AllowClobber"
} else {

    # Settings for the prompt are in GitPrompt.ps1, so add any desired settings changes here.
    # Example:
    #     $Global:GitPromptSettings.BranchBehindAndAheadDisplay = "Compact"

    # Start-SshAgent -Quiet   # Not needed any more?
}

# Other modules
Invoke-Expression -Command $PSScriptRoot\Modules\Posh-GitHub\Posh-GitHub-Profile.ps1
$VSSetupModule = Get-Module -Name VSSetup
if ((Test-HasVisualStudio) -and ($null -eq $VSSetupModule)) {
    Import-Module -Name $PSScriptRoot\MyModules\Posh-VsVars
}
Remove-Item -Path Variable:VSSetupModule

Stop-Timing -Description "posh-git took"

#
# Third party modules that do not require special initialization
#

Start-Timing

# The following three are included as submodules

if (Test-Path -Path $env:ChocolateyInstall\helpers\chocolateyInstaller.psm1 -PathType Leaf) {
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1" -Force
}

# Not needed here, we have imported it above:
# Import-Module PowerShellCookbook -ErrorAction SilentlyContinue
$cwcmd = Get-Command -Name New-CommandWrapper -ErrorAction SilentlyContinue
if ($null -eq $cwcmd) {
    . .\customize-console-output.ps1
}



Stop-Timing -Description "Third party modules took"

#
# Command overrides
#

Start-Timing

try {
    # test that the GetCommand takes 3 argument, if not it will throw an exception and we will not overload gci
    $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Management\Get-ChildItem', [System.Management.Automation.CommandTypes]::Cmdlet, "") | Out-Null
    . $PSScriptRoot\Overrides\Get-ChildItem.ps1
}
catch {
    # do nothing; keep standard gci
}

if ($null -eq (Get-Module -Name xUtility -ListAvailable)) {
    . $PSScriptRoot\Overrides\Set-LocationWithHints.ps1
} else {
    Write-Warning -Message "Consider installing xUtility (admin):  Install-Module -Name xUtility -Force -AllowClobber"
}

Stop-Timing -Description "Command overrides"

#
# Command line fuzzy finder
#

if (Get-Module -Name PSFzf -ListAvailable -ErrorAction SilentlyContinue) {
    if (-not (Get-Module -Name PSFzf -ErrorAction SilentlyContinue)) {
        # Module PSFzf exists and it is not loaded

        if (Get-Command -Name fzf -ErrorAction SilentlyContinue) {
            Import-Module PSFzf -ArgumentList 'Ctrl+T','Ctrl+Alt+R','Alt+C','Alt+A'
        } else {
            Write-Warning -Message "Consider installing fzf, e.g. cinst -y fzf"
        }
    }
}

#
# Setup ripgrep (rg) if available
#

Start-Timing

$rgcommand = Get-Command -Name rg -ErrorAction SilentlyContinue
if ($rgcommand) {
    $rgreal = Get-ShimProperties -ProgramName rg
    if ($null -eq $rgreal) {
        $rgpath = $rgcommand.Path
    } else {
        $rgpath = $rgreal.Path
    }

    $rgdir = Split-Path -Path $rgPath -Parent
    $rgconf = Join-Path -Path $rgdir -ChildPath _rg.ps1
    if (Test-Path -Path $rgconf -PathType Leaf) {
        . "$rgconf"
    }

    Set-Item -Path function:grep -Value {
        $count = @($input).Count
        $input.Reset()

        if ($count) { $input | rg.exe --colors 'path:bg:green' --colors 'match:style:intense' --hidden $args }
        else { rg.exe --colors 'path:bg:green' --colors 'match:style:intense' --hidden $args }
    }
}

Stop-Timing -Description "Stop timing: setting up ripgrep (rg)"

#
# Setting up the
#

Start-Timing

if (Get-Command -Name thefuck -ErrorAction SilentlyContinue) {
    $env:PYTHONIOENCODING='utf-8'
    function fuck {
        $history = (Get-History -Count 1).CommandLine;
        if (-not [string]::IsNullOrWhiteSpace($history)) {
            $fuck = $(thefuck $args $history);
            if (-not [string]::IsNullOrWhiteSpace($fuck)) {
                if ($fuck.StartsWith("echo")) { $fuck = $fuck.Substring(5); }
                else { Invoke-Expression "$fuck"; }
            }
        }
    }
} else {
    Write-Warning -Message "Cannot load thefuck system"
}


Stop-Timing -Description "Stop timing: setting up command corrections"

# Dynamic module loader
$dynamic_module_loader = Join-Path -Path $PSScriptRoot -ChildPath packages | Join-Path -ChildPath DynamicPackageLoader.psm1
if (Test-Path -Path $dynamic_module_loader -PathType Leaf) {
    $loader = Get-Item -Path $dynamic_module_loader
    Push-Location -Path $loader.DirectoryName
    Try {
        Import-Module -Name Pipeworks
        Import-Module -Name ./DynamicPackageLoader -Prefix DynamicLoader
    } Finally {
        Pop-Location
    }
    Write-Warning -Message "If you see errors related to module log4net use:`n          Register-DynamicLoaderExtraPackages"
}

#
# End of initialization
#

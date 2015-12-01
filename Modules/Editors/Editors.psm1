function Open-InNotepad {
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNull]
        [System.IO.FileInfo]
        $File
    )

    notepad $File
    $notepad = Get-Process -Name notepad
    [WindowingTricks]::SetForegroundWindow($notepad.MainWindowHandle)
}

function Open-InNotepadPlusPlus {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "Open-InNotepadPlusPlus")]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNull]
        [System.IO.FileInfo]
        $File
    )

    if (Test-HasNotepadPlusPlus) {
        $npp = Get-NotepadPlusPlusPath
        $cmd = "& '$npp' $File"
        Invoke-Expression -Command $cmd
        $wnd = Get-Process -Name notepad++
        [WindowingTricks]::SetForegroundWindow($wnd.MainWindowHandle)
    } else {
        Open-InNotepad -File $file
    }
}

function Open-InEmacs {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "Open-InEmacs")]
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNull]
        [System.IO.FileInfo]
        $File,

        [Switch]
        $NoWait
    )

    if (Test-HasEmacs) {
        if ($NoWait) {
            $emacsNoWait = '-n'
        } else {
            $emacsNoWait = ''
        }

        $currentWindow = [WindowingTricks]::GetForegroundWindow()

        $emacs = Get-Process -Name emacs -ErrorAction SilentlyContinue
        if ($null -eq $emacs) {
            runemacs
            Read-Host -Prompt "Press <ENTER> after emacs initializes"
            $emacs = Get-Process -Name emacs -ErrorAction SilentlyContinue
        }

        [WindowingTricks]::SetForegroundWindow($emacs.MainWindowHandle)
        emacsclient $emacsNoWait $File

        if (-not $NoWait) {
            # TODO The following does not work:
            # it gets executed, but does not change the focus from emacs to window;
            # even though it does change the focus between powershell windows
            [WindowingTricks]::SetForegroundWindow($currentWindow)
        }
    } else {
        Open-InNotepadPlusPlus -File $File
    }
}

function Open-InPowerShellIse {
    param(
        [parameter(Mandatory=$true)]
        [ValidateNotNull]
        [System.IO.FileInfo]
        $File
    )

    powershell_ise.exe $File
}


<#
.SYNOPSIS
Opens a file with an appropriate editor.

.DESCRIPTION
The Get-FileInEditor attempts to open a file using an appropriate editor. It will guess the editor based on suffix
and various heuristics. For example, LaTeX related files open with emacs; solution and project files with VS.


.PARAMETER Filename
The name of the file to open.


.PARAMETER NoWait
Do not wait the editor to finish with the file before continuing.


.EXAMPLE

Create a new file, or open the existing main.tex file.
Get-FileInEditor main.tex

#>
function Get-FileInEditor {
    [CmdletBinding()]
    param(
        [string]
        $Filename = $Editors.Session.LastFile,

        [Switch]
        $NoWait
    )

    if ([System.String]::IsNullOrWhiteSpace($Filename)) {
        $Filename = $Editors.Session.LastFile
    } elseif (Test-Path -Path $Filename) {
        $fullName = (Get-Item -Path $Filename).FullName
        $Script:Editors.Session.LastFile = $fullName

        if (-not $Script:Editors.Session.Files.Contains($fullName)) {
            $Script:Editors.Session.Files.Add($fullName)
        }
    } else {
        $nf = [System.IO.FileInfo]::New($Filename)
        $Script:Editors.Session.LastFile = $nf.FullName

        if (-not $Script:Editors.Session.Files.Contains($nf.FullName)) {
            $Script:Editors.Session.Files.Add($nf.FullName)
        }
    }

    if ([System.String]::IsNullOrWhiteSpace($Filename)) {
        Write-Error -Message "Name of input file cannot be null or empty."
        throw [System.ArgumentNullException] "Input file has null or empty name."
    }

    if (Test-Path -Path $Filename -PathType Container) {
        explorer $Filename
    } else {
        $o = New-Object -TypeName System.IO.FileInfo -ArgumentList $Filename

        if ($NoWait) {
            $emacsNoWait = '-n'
        } else {
            $emacsNoWait = ''
        }

        if ($o.Extension -in '.tex', '.bib') {
            Open-InEmacs -NoWait:$NoWait.IsPresent -File $o
        } elseif ($o.Extension -in '.c', '.h', '.cpp', '.hpp') {
            Open-InEmacs -NoWait:$NoWait.IsPresent -File $o
        } elseif ($o.Extension -in '.cs', '.fs', '.fsi', '.fsx', '.sln', 'csproj', 'fsproj') {
            Open-InEmacs -NoWait:$NoWait.IsPresent -File $o
        } elseif ($o.Extension -in '.ml', '.mli') {
            Open-InEmacs -NoWait:$NoWait.IsPresent -File $o
        } elseif ($o.Extension -in '.tab', '.csv', '.txt') {
            Open-InEmacs -NoWait:$NoWait.IsPresent -File $o
        } elseif ($o.Extension -in '.html', '.htm', '.css') {
            Open-InEmacs -NoWait:$NoWait.IsPresent -File $o
        } elseif ($o.Extension -in '.org', '.el') {
            Open-InEmacs -NoWait:$NoWait.IsPresent -File $o
        } elseif ($o.Name -in 'README.md', '.gitignore') {
            Open-InEmacs -NoWait:$NoWait.IsPresent -File $o
        } elseif ($o.Extension -in '.ps1', '.psd1', '.psm1', '.ps1xml', '.cdxml') {
            Open-InPowerShellIse -File $o
        } elseif ($o.Extension.StartsWith('.pssc')) {
            Open-InPowerShellIse -File $o
        } else {
            Open-InNotepadPlusPlus $o
        }
    }
}

<#
.SYNOPSIS
    Lists the recently opened files.

.DESCRIPTION
    Returns a list of the files that have been opened recently.
#>
function Get-FileEditHistory {
    $Editors.Session.Files
}

$Editors = @{}
$Editors.Session = @{}
$Editors.Session.Files = New-Object -TypeName System.Collections.Generic.List``1[string]
$Editors.Session.LastFile = ""

Set-Alias -Name e -Value Get-FileInEditor
<#
.SYNOPSIS
    Opens a file with an appropriate editor. 
    Unlike e, it does not wait for the editor to return.
#>
function en { param($Filename = $Editors.Session.LastFile); Get-FileInEditor -NoWait -Filename $Filename }

Export-ModuleMember -Function Get-FileInEditor
Export-ModuleMember -Function Get-FileEditHistory
Export-ModuleMember -Function en
Export-ModuleMember -Variable Editors
Export-ModuleMember -Alias e
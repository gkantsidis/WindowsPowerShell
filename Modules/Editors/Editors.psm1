function Open-InNotepad {
    param(
        [System.IO.FileInfo]
        $File
    )

    notepad $File
    $notepad = Get-Process emacs
    [WindowingTricks]::SetForegroundWindow($notepad.MainWindowHandle)
}

function Open-InNotepadPlusPlus {
    param(
        [System.IO.FileInfo]
        $File
    )

    if (Test-HasNotepadPlusPlus) {
        $npp = Get-NotepadPlusPlusPath
        $cmd = "& '$npp' $File"
        Invoke-Expression $cmd
        $wnd = Get-Process notepad++
        [WindowingTricks]::SetForegroundWindow($wnd.MainWindowHandle)
    } else {
        Open-InNotepad -File $file
    }
}

function Open-InEmacs {
    param(
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

        $emacs = Get-Process emacs -ErrorAction SilentlyContinue
        if ($emacs -eq $null) {
            runemacs
            Read-Host -Prompt "Press <ENTER> after emacs initializes"
            $emacs = Get-Process emacs -ErrorAction SilentlyContinue
        }

        [WindowingTricks]::SetForegroundWindow($emacs.MainWindowHandle)
        emacsclient $emacsNoWait $File
    } else {
        Open-InNotepadPlusPlus -File $File
    }
}

function Open-InPowerShellIse {
    param(
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
        $Filename,

        [Switch]
        $NoWait
    )

    if ([System.String]::IsNullOrWhiteSpace($Filename)) {
        $Filename = $Editors.Session.LastFile
    } else {
        $Global:Editors.Session.LastFile = $Filename
    }

    if ([System.String]::IsNullOrWhiteSpace($Filename)) {
        Write-Error "Name of input file cannot be null or empty."
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

$Editors = @{}
$Editors.Session = @{}
$Editors.Session.LastFile = ""

Set-Alias -Name e -Value Get-FileInEditor
function en { param($Filename); Get-FileInEditor -NoWait -Filename $Filename }

Export-ModuleMember -Function Get-FileInEditor
Export-ModuleMember -Function en
Export-ModuleMember -Variable Editors
Export-ModuleMember -Alias e
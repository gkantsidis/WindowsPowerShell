
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
        $Filename = $EditorsLastFile
    } else {
        $Global:EditorsLastFile = $Filename
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
            emacsclient $emacsNoWait $o
        } elseif ($o.Extension -in '.c', '.h', '.cpp', '.hpp') {
            emacsclient $emacsNoWait $o
        } elseif ($o.Extension -in '.cs', '.fs', '.fsi', '.fsx', '.sln', 'csproj', 'fsproj') {
            emacsclient $emacsNoWait $o
        } elseif ($o.Extension -in '.tab', '.csv', '.txt') {
            emacsclient $emacsNoWait $o
        } elseif ($o.Extension -in '.html', '.htm', '.css') {
            emacsclient $emacsNoWait $o
        } elseif ($o.Extension -in '.org', '.el') {
            emacsclient $emacsNoWait $o            
        } elseif ($o.Name -in 'README.md', '.gitignore') {
            emacsclient $emacsNoWait $o
        } else {
            notepad $o
        }
    }
}

$EditorsLastFile = ""

Export-ModuleMember -Function Get-FileInEditor
Export-ModuleMember -Variable EditorsLastFile
function Test-HasVisualStudio {
	$vs = Get-ChildItem HKLM:\SOFTWARE\Microsoft\VisualStudio\[0-9]*
	-not ($vs -eq $null)
}

function Test-HasChocolatey {
    $choco = Get-Command choco
    -not ($choco -eq $null)
}

function Test-HasEmacs {
    $emacs = Get-Command emacsclient
    -not ($emacs -eq $null)
}

function Test-IsIse {
    try
    {
        return $psISE -ne $null
    }
    catch
    {
        return false
    }
}

function Test-HasNotepadPlusPlus {
    return (Test-Path -Path 'C:\Program Files (x86)\Notepad++\notepad++.exe' -PathType Leaf)
}

function Get-NotepadPlusPlusPath {
    if (Test-HasNotepadPlusPlus) {
        'C:\Program Files (x86)\Notepad++\notepad++.exe'
    } else {
        Write-Error "Notepad++ does not exist in this system"
        Throw "Notepad++ does not exist in this system"
    }
}
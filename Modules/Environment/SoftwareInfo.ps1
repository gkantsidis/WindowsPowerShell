function Test-HasVisualStudio {
    $vs = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\VisualStudio\[0-9]* -ErrorAction SilentlyContinue
    -not ($null -eq $vs)
}

function Test-HasChocolatey {
    $choco = Get-Command -Name choco -ErrorAction SilentyContinue
    -not ($null -eq $choco)
}

function Test-HasEmacs {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "Test-HasEmacs")]
    param()

    $emacs = Get-Command -Name emacsclient -ErrorAction SilentyContinue
    -not ($null -eq $emacs)
}

function Test-IsIse {
    try
    {
        return $null -ne $psISE
    }
    catch
    {
        return $false
    }
}

function Test-HasNotepadPlusPlus {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "Test-HasNotepadPlusPlus")]
    param()

    return (Test-Path -Path 'C:\Program Files (x86)\Notepad++\notepad++.exe' -PathType Leaf)
}

function Get-NotepadPlusPlusPath {
    if (Test-HasNotepadPlusPlus) {
        'C:\Program Files (x86)\Notepad++\notepad++.exe'
    } else {
        Write-Error -Message "Notepad++ does not exist in this system"
        Throw "Notepad++ does not exist in this system"
    }
}
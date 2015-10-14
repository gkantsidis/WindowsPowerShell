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
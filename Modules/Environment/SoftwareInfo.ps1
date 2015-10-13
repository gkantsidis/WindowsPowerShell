function Has-VisualStudio {
	$vs = Get-ChildItem HKLM:\SOFTWARE\Microsoft\VisualStudio\[0-9]*
	-not ($vs -eq $null)
}

function Has-Chocolatey {
    $choco = Get-Command choco
    -not ($choco -eq $null)
}

function Has-Emacs {
    $emacs = Get-Command emacsclient
    -not ($emacs -eq $null)
}
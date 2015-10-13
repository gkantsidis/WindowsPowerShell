function Has-VisualStudio {
	$vs = Get-ChildItem HKLM:\SOFTWARE\Microsoft\VisualStudio\[0-9]*
	-not ($vs -eq $null)
}
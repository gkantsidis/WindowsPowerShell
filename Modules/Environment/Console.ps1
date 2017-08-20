
$OrigFgColor = $Host.UI.RawUI.ForegroundColor

<#
.SYNOPSIS
Resets console's default color

.DESCRIPTION
Reset the color of the console to the one it had when the console started.

.EXAMPLE
Reset the color of the console to its default:
  Reset-ForegroundColor

.NOTES
Code taken from https://github.com/BurntSushi/ripgrep.
#>
function Reset-ForegroundColor {
	$Host.UI.RawUI.ForegroundColor = $OrigFgColor
}

Set-Alias -Name color -Value Reset-ForegroundColor
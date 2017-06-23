#Requires -Module Environment
#Requires -Module posh-git

function Get-HardwareInfo {
    $hw = Get-HwInfo
    Write-Output "$($hw.Name).$($hw.Domain): $($hw.Manufacturer) $($hw.Model)"
}

function Get-SourceInformation {
    [CmdletBinding()]
    param(
        [Microsoft.PowerShell.EditorServices.Extensions.EditorContext]$context
    )

    $path = Split-Path -Parent -Path $context.CurrentFile
    Push-Location $path
    $git = Get-GitDirectory
    Pop-Location

    $location = "$($context.CurrentFile.Path):$($context.CursorPosition.Line),$($context.CursorPosition.Column)"
    if ([string]::IsNullOrWhiteSpace($git)) {
        Write-Output "$location`t (not under git)"
    } else {
        $info = Get-GitStatus -gitDir $git
        $repo = Split-Path -Parent -Path $git

        $branch = $info.Branch
        $repostatus = Get-GitRepositoryStatus -RepoRoot $repo

        $flags = ""
        if ($repostatus.IsConflicted) { $flags += "!" }
        if ($repostatus.IsModified) { $flags += "*" }
        if ($repostatus.IsAdded) { $flags += "+" }
        if ($repostatus.IsDeleted) { $flags += "-" }

        Write-Output "$flags`t$branch`t$location"
    }
}
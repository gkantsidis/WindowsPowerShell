# $git = Get-command -Name git
# $gitDir = Get-Item -Path $git.Path
# $folder = Join-Path -Path $gitDir.Directory.FullName -ChildPath ".." | `
          # Join-Path -ChildPath "usr" | `
          # Join-Path -ChildPath "bin"

# $Env:Path = $Env:Path + ";$folder"

#####ISEPESTER#####
Import-Module $Env:ChocolateyInstall\lib\IsePester\tools\IsePester.psm1
Import-Module $Env:ChocolateyInstall\lib\pester\tools\Pester.psm1
#####ISEPESTER#####
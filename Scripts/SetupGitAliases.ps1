<#
.SYNOPSIS
    Setup Git Aliases

.DESCRIPTION
    Adds convenient Git aliases to the current user's .gitconfig file.

.NOTES
    Aliases adapted from https://github.com/Iristyle/ChocolateyPackages/blob/master/EthanBrown.GitAliases/tools/chocolateyInstall.ps1,
    which in turn uses  https://git.wiki.kernel.org/index.php/Aliases, https://gist.github.com/oli/1637874,
    and https://gist.github.com/bradwilson/4215933.
#>

[CmdletBinding()]
param(
)

try {
    # partially inspired by
    # https://git.wiki.kernel.org/index.php/Aliases
    # https://gist.github.com/oli/1637874
    # https://gist.github.com/bradwilson/4215933

    git config --global alias.aliases 'config --get-regexp alias'
    git config --global alias.amend 'commit --amend'
    git config --global alias.bl 'blame -w -M -C'
    git config --global alias.bra 'branch -rav'
    git config --global alias.branches 'branch -rav'
    git config --global alias.changed 'status -sb'
    git config --global alias.f '!git ls-files | grep -i'
    git config --global alias.filelog 'log -u'
    git config --global alias.hist "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue) [%an]%Creset' --abbrev-commit --date=relative"
    git config --global alias.last 'log -p --max-count=1 --word-diff'
    git config --global alias.lastref 'rev-parse --short HEAD'
    git config --global alias.lasttag 'describe --tags --abbrev=0'
    git config --global alias.pick 'add -p'
    git config --global alias.remotes 'remote -v show'
    git config --global alias.stage 'add'
    $userName = git config --global --get user.name
    if ($userName)
    {
      git config --global alias.standup "log --since yesterday --oneline --author '$userName'"
    }
    else
    {
      Write-Warning "Set git global username with git config --global user.name 'foo' to use standup"
    }
    git config --global alias.stats 'diff --stat'
    git config --global alias.sync '! git fetch upstream -v && git fetch origin -v && git checkout master && git merge upstream/master'
    git config --global alias.undo 'reset head~'
    git config --global alias.unstage 'reset HEAD'
    git config --global alias.wdiff 'diff --word-diff'
    git config --global alias.who 'shortlog -s -e --'

    Write-Verbose "Git aliases installed"
  } catch {
    Write-Error -Message "Installation failed with error: $($_.Exception.Message)"
    throw
  }


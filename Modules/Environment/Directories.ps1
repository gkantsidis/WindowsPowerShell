# Some shortcuts that make life easier  

function Get-ChildItemByPage { Get-ChildItem $args | more }

function Get-ChildItemWithOwner { Get-ChildItem $args | Get-Acl | Select-Object Path,Owner }

function Get-ChildItemWithHidden { 
    $result = Get-ChildItem $args
    $hidden = $result | ForEach-Object -Process {
        Get-Item $_.FullName -Stream * | `
        Where-Object -Property Stream -NE -Value ":`$DATA"
    }
    $result = $result + $hidden
    $result
}

Set-Alias -Name "dir/p" -Value Get-ChildItemByPage
Set-Alias -Name "dir/q" -Value Get-ChildItemWithOwner
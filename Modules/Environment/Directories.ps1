# Some shortcuts that make life easier

function Get-ChildItemByPage { Get-ChildItem $args | more }

function Get-ChildItemWithOwner { Get-ChildItem $args | Get-Acl | Select-Object Path,Owner }

function Get-ChildItemWithStreams {
    $result = Get-ChildItem $args
    [object[]]$everything = $result | ForEach-Object -Process {
        $_
        $mystreams = Get-Item $_.FullName -Stream * -ErrorAction SilentlyContinue | `
                     Where-Object -Property Stream -NE -Value ":`$DATA"
        $mystreams
    }
    $everything
}

function Get-ChildItemWithHidden {
    [object[]]$visible = Get-ChildItem $args
    [object[]]$hidden = Get-ChildItem -Hidden $args
    $result = $visible + $hidden
    [object[]]$everything = $result | ForEach-Object -Process {
        $_
        $mystreams = Get-Item $_.FullName -Stream * -ErrorAction SilentlyContinue | `
                     Where-Object -Property Stream -NE -Value ":`$DATA"
        $mystreams
    }
    $everything
}

Set-Alias -Name "dir/a" -Value Get-ChildItemWithHidden
Set-Alias -Name "dir/p" -Value Get-ChildItemByPage
Set-Alias -Name "dir/q" -Value Get-ChildItemWithOwner
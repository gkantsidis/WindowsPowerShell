# Some shortcuts that make life easier

function Get-ChildItemByPage { Get-ChildItem @args | more }

function Get-ChildItemWithOwner { Get-ChildItem @args | Get-Acl | Select-Object Path,Owner }

function Get-ChildItemWithStreams {
    Get-ChildItem @args | ForEach-Object -Process {
        Write-Output -InputObject $_
        $mystreams = Get-Item $_.FullName -Stream * -ErrorAction SilentlyContinue | `
                     Where-Object -Property Stream -NE -Value ":`$DATA"
        Write-Output -InputObject $mystreams
    }
}

function Get-ChildItemWithHidden {
    # There is redundancy in the code below, but this way we get the output
    # pipeline working better.

    Get-ChildItem @args | ForEach-Object -Process {
        $item = $_
        Write-Output -InputObject $item
        if (Get-Member -InputObject $item -Name FullName -ErrorAction SilentlyContinue) {
            $mystreams = Get-Item $item.FullName -Stream * -ErrorAction SilentlyContinue | `
                        Where-Object -Property Stream -NE -Value ":`$DATA"
            Write-Output -InputObject $mystreams
        }
    }
    Get-ChildItem -Hidden @args | ForEach-Object -Process {
        $item = $_
        Write-Output -InputObject $item
        if (Get-Member -InputObject $item -Name FullName -ErrorAction SilentlyContinue) {
            $mystreams = Get-Item $item.FullName -Stream * -ErrorAction SilentlyContinue | `
                        Where-Object -Property Stream -NE -Value ":`$DATA"
            Write-Output -InputObject $mystreams
        }
    }
}

Set-Alias -Name "dir/a" -Value Get-ChildItemWithHidden
Set-Alias -Name "dir/p" -Value Get-ChildItemByPage
Set-Alias -Name "dir/q" -Value Get-ChildItemWithOwner
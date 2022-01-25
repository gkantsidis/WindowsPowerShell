# Simple tool that calls the F# compiler that is associated with dotnet.
# In summary, it detects the location of the F# compiler and calls the
# executable through dotnet, passing all arguments to the compiler.

$info = dotnet --info | Select-String "Base Path:"
$path = $info -match ' Base Path:\s+(.*)$'
$path = $Matches[1].Trim()
$candidate = Join-Path -Path $path -ChildPath "FSharp" | Join-Path -ChildPath "fsc.exe"

if (-not (Test-Path $candidate)) {
    Write-Error -Message "Did not find F# in <$candidate>"
}
dotnet $candidate $args

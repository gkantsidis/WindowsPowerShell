<#
 .SYNOPSIS
 Changes a UTF-16 file to make it ASCII. The change happens in binary level.
 This script is very brittle, but it does the job where some other tools fail.
 It assumes that the input file is indeed composed only of ASCII characters.

 .NOTES
 Some of the problems:

 The output text file does not render well in notepad.
 A combination of Get-Content with Out-File solves the problem.

 The output file is stored under the user profile directory,
 and not the current directory.

 Unclear, how this script will deal with files that have extended characters.
 #>

[CmdletBinding()]
param(
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    [String]$FilePath,

    [ValidateNotNullOrEmpty()]
    [ValidateScript({-not (Test-Path -Path $_)})]
    [String]$OutputFile
)

$real_file_path = Get-Item -Path $FilePath
$full_file_path = $real_file_path.FullName
Write-Verbose -Message "Input file: $full_file_path"
[System.IO.FileStream]$read_handler = [System.IO.File]::Open($full_file_path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
[System.IO.FileStream]$write_handler = [System.IO.File]::Open($OutputFile, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

[System.IO.BinaryReader]$reader = [System.IO.BinaryReader]::new($read_handler)
[System.IO.BinaryWriter]$writer = [System.IO.BinaryWriter]::new($write_handler)

$magic = [uint16]0xfeff # remember that this is little endian

$header = $reader.ReadUInt16()
if ($header[0] -ne $magic) {
    Write-Error -Message "File does not appear to be unicode"
    return
}

[byte]$end_line_1 = [byte]0x0D
[byte]$end_line_2 = [byte]0x0A
[byte]$zero_byte = [byte]0x00
while($read_handler.Position -lt $read_handler.Length) {
    [byte]$b1 = $reader.ReadByte()
    if ($read_handler.Position -eq $read_handler.Length) {
        continue
    }
    [byte]$b2 = $reader.ReadByte()

    if (($b1 -eq $end_line_1) -and ($b2 -eq $end_line_2)) {
        $writer.Write($b1)
        $writer.Write($b2)
    } else {
        if ($b1 -eq $zero_byte) {
            $b = $b2
        } else {
            $b = $b1
        }
        if ($b -eq $end_line_1) {
            continue
        } else {
            $writer.Write($b)
        }
    }
}

$reader.Dispose()
$writer.Dispose()
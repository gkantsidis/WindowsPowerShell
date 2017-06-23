#Requires -Version 5.0
#Requires -Module PowerShellEditorServices

class Editor : Microsoft.PowerShell.EditorServices.Extensions.IEditorOperations
{
    [System.Threading.Tasks.Task[Microsoft.PowerShell.EditorServices.Extensions.EditorContext]] GetEditorContext()
    {
        throw "Not implemented"
    }

    [string] GetWorkspacePath()
    {
        throw "Not implemented"
    }

    [string] GetWorkspaceRelativePath([string] $filePath)
    {
        throw "Not implemented"
    }

    [System.Threading.Tasks.Task] NewFile()
    {
        throw "Not implemented"
    }

    [System.Threading.Tasks.Task] OpenFile([string] $filePath)
    {
        throw "Not implemented"
    }

    [System.Threading.Tasks.Task] CloseFile([string] $filePath)
    {
        throw "Not implemented"
    }

    [System.Threading.Tasks.Task] InsertText([string] $filePath, [string] $insertText, [Microsoft.PowerShell.EditorServices.BufferRange] $insertRange)
    {
        throw "Not implemented"
    }

    [System.Threading.Tasks.Task] SetSelection([Microsoft.PowerShell.EditorServices.BufferRange] $selectionRange)
    {
        throw "Not implemented"
    }

    [System.Threading.Tasks.Task] ShowInformationMessage([string] $message)
    {
        throw "Not implemented"
    }

    [System.Threading.Tasks.Task] ShowErrorMessage([string] $message)
    {
        throw "Not implemented"
    }

    [System.Threading.Tasks.Task] ShowWarningMessage([string] $message)
    {
        throw "Not implemented"
    }

    [System.Threading.Tasks.Task] SetStatusBarMessage([string] $message, [Nullable[int]] $timeout)
    {
        throw "Not implemented"
    }
}

function Invoke-VSCFunction {
    <#
    .SYNOPSIS
    Invoke a function that is typically called inside Visual Studio Code

    .DESCRIPTION
    Long description

    .PARAMETER Name
    Name of function

    .PARAMETER Line
    Line in the file of the cursor.

    .PARAMETER Column
    Column in the file of the cursor.

    .PARAMETER PowerShellVersion
    Version of PowerShell

    .EXAMPLE
    An example

    .NOTES
    General notes
    #>

    [CmdletBinding()]
    param(
        [ValidateNotNull()]
        [string]$Name,

        [Hashtable]$CallArguments,

        [ValidateNotNull()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$FilePath,

        [ValidateNotNull()]
        [ValidateScript({Test-Path -Path $_})]
        [string]$ClientFilePath,

        [ValidateScript({$_ -gt 0})]
        [int]$Line = 1,
        [ValidateScript({$_ -gt 0})]
        [int]$Column = 1,

        [ValidateNotNull()]
        [Editor]$Editor = [Editor]::new(),

        [ValidateNotNull()]
        [string]$PowerShellVersion = $PSVersionTable.PSVersion
    )

    <#
     # Microsoft.PowerShell.EditorServices.Extensions.IEditorOperations editorOperations,
     # Microsoft.PowerShell.EditorServices.ScriptFile currentFile,
     # Microsoft.PowerShell.EditorServices.BufferPosition cursorPosition,
     # Microsoft.PowerShell.EditorServices.BufferRange selectedRange
     #  -> Microsoft.PowerShell.EditorServices.Extensions.EditorContext
     #
     # string filePath, string clientFilePath, version powerShellVersion -> ScriptFile
     # int line, int column -> BufferPosition
     #>


     $currentFile = [Microsoft.PowerShell.EditorServices.ScriptFile]::new($FilePath, $ClientFilePath, $PowerShellVersion)
     $cursorPosition = [Microsoft.PowerShell.EditorServices.BufferPosition]::new($Line, $Column)
     $selectedRange = [Microsoft.PowerShell.EditorServices.BufferRange]::None

     $context = [Microsoft.PowerShell.EditorServices.Extensions.EditorContext]::new($Editor, $currentFile, $cursorPosition, $selectedRange)

     if ($CallArguments -eq $null) {
         $CallArguments = @{
             context = $context
         }
     } else {
         Write-Verbose "?? $context"
         Write-Verbose "?? $CallArguments"
         $CallArguments.Add("context", $context)
     }

     &"$Name" @CallArguments
}
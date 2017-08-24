#Requires -Module PSReflect-Functions

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProcessName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName
)

Write-Warning -Message "VERY DANGEROUS: expect exceptions, process crashing, and system stability problems!!!"

[System.Diagnostics.Process[]]$process = Get-Process -Name $ProcessName
if (($process -eq $null) -or ($process.Length -eq 0)) {
    Write-Error -Message "Cannot find any process with the name '$ProcessName'"
}
if ($process.Length -gt 1) {
    Write-Warning -Message "Found multiple processes, picking first '$($process[0].Name)' with pid: $($process[0].Id)"
}
$process = $process[0]

$kernel32 = GetModuleHandle kernel32
$free = GetProcAddress -ModuleHandle $kernel32 -FunctionName FreeLibrary

if (-not $ModuleName.EndsWith(".dll")) {
    $ModuleName = "{0}.dll" -f $ModuleName
}

try {
    $processHandle = OpenProcess -ProcessId $process.Id -DesiredAccess PROCESS_CREATE_THREAD,PROCESS_QUERY_INFORMATION,PROCESS_VM_OPERATION,PROCESS_VM_WRITE,PROCESS_VM_READ -InheritHandle $false
    $modules = EnumProcessModules -ProcessHandle $processHandle
    $module = $modules | Where-Object -FilterScript {
        $name = GetModuleBaseName -ProcessHandle $processHandle -ModuleHandle $_
        $name -eq $ModuleName
    }

    Write-Verbose -Message "Found module $module; will try to unload"

    $threadInfo = CreateRemoteThread -ProcessHandle $processHandle `
                                     -EntryPoint $free `
                                     -Parameter $module

    Write-Output $threadInfo
}
finally {
    CloseHandle -Handle $processHandle
}
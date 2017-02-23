function Save-EnvironmentSettings {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = "$Env:USERPROFILE\Settings\Environment\Backup",

        [ValidateNotNullOrEmpty()]
        [string]
        $Name = [System.String]::Format("{0}.settings", [System.DateTime]::Now.ToUniversalTime().ToString("yyyyMMdd-hhmmss")),

        [switch]
        $SaveMachineSpecific
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-Verbose -Message "Creating directory $Path for settings"
        New-Item -Path $Path -ItemType Directory -Force
    }
    $file = Join-Path -Path $Path -ChildPath $Name
    if (Test-Path -Path $file) {
        Write-Error -Message "Target file $file already exists" -RecommendedAction "Please use another filename, or delete existing file"
        throw "Existing output file"
    }

    $settings = Get-ChildItem Env: -Recurse
    if (-not $SaveMachineSpecific) {       
        $settings = $settings | ForEach-Object -Process {
            $entry = $_
            if ( ($entry.Name -match "^PROCESSOR")  -or
                 ($entry.Name -match "SSH_") -or
                 ($entry.Name -match "OS") -or
                 ($entry.Name -match "NUMBER_OF_PROCESSORS") -or
                 ($entry.Name -match "SESSIONNAME") -or
                 ($entry.Name -match "^USERDOMAIN") -or
                 ($entry.Name -match "USERDNSDOMAIN")
               ) 
            {
                # Ignore
            } else {
                $entry
            }
        }
    }

    $settings | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $file -NoClobber
}
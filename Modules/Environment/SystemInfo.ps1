function Get-OsInfo {
	param(
	    [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Connection -ComputerName $_ -Count 1 -Quiet})]
		[string[]]
		$ComputerName = "localhost"
	)

    BEGIN {}
    PROCESS {
        foreach ($computer in $ComputerName) {
	        Get-CimInstance -ClassName CIM_OperatingSystem -ComputerName $computer
        }
    }
    END {}
}

function Get-HwInfo {
    param(
	    [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Connection -ComputerName $_ -Count 1 -Quiet})]
		[string[]]
		$ComputerName = "localhost"
	)

    BEGIN {}
    PROCESS {
        foreach ($computer in $ComputerName) {
	        Get-CimInstance -ClassName CIM_ComputerSystem -ComputerName $computer
        }
    }
    END {}
}

#Requires -Module ActiveDirectory

# Script from https://gallery.technet.microsoft.com/scriptcenter/Get-ADDirectReport-962616c6

function Get-ADDirectReports
{
	<#
	.SYNOPSIS
		This function retrieve the directreports property from the IdentitySpecified.
		Optionally you can specify the Recurse parameter to find all the indirect
		users reporting to the specify account (Identity).
	
	.DESCRIPTION
		This function retrieve the directreports property from the IdentitySpecified.
		Optionally you can specify the Recurse parameter to find all the indirect
		users reporting to the specify account (Identity).
	
	.NOTES
		Francois-Xavier Cat
		www.lazywinadmin.com
		@lazywinadm
	
		VERSION HISTORY
		1.0 2014/10/05 Initial Version
	
	.PARAMETER Identity
		Specify the account to inspect
	
	.PARAMETER Recurse
		Specify that you want to retrieve all the indirect users under the account
	
	.EXAMPLE
		Get-ADDirectReports -Identity Test_director
	
Name                SamAccountName      Mail                Manager
----                --------------      ----                -------
test_managerB       test_managerB       test_managerB@la... test_director
test_managerA       test_managerA       test_managerA@la... test_director
		
	.EXAMPLE
		Get-ADDirectReports -Identity Test_director -Recurse
	
Name                SamAccountName      Mail                Manager
----                --------------      ----                -------
test_managerB       test_managerB       test_managerB@la... test_director
test_userB1         test_userB1         test_userB1@lazy... test_managerB
test_userB2         test_userB2         test_userB2@lazy... test_managerB
test_managerA       test_managerA       test_managerA@la... test_director
test_userA2         test_userA2         test_userA2@lazy... test_managerA
test_userA1         test_userA1         test_userA1@lazy... test_managerA
	
	#>
	[CmdletBinding()]
	PARAM (
		[Parameter(Mandatory)]
		[String[]]$Identity,
		[Switch]$Recurse,
		[Switch]$SuppressError
	)
	BEGIN
	{
		$shouldUnloadModule = $false
		TRY
		{
			IF (-not (Get-Module -Name ActiveDirectory)) { 
				Import-Module -Name ActiveDirectory -ErrorAction 'Stop' -Verbose:$false
				$shouldUnloadModule = $true
			}
		}
		CATCH
		{
			Write-Verbose -Message "[BEGIN] Something wrong happened"
			Write-Verbose -Message $Error[0].Exception.Message
		}

		$queue = New-Object -TypeName 'System.Collections.Generic.Queue[string]' -ArgumentList @(,$Identity)
	}
	PROCESS
	{
		while($queue.Count -gt 0) {
			$current = $queue.Dequeue()

			if (-not $current.StartsWith("CN=", [System.StringComparison]::InvariantCultureIgnoreCase)) {
				Write-Verbose -Message "Identity '$current' not in canonical form"
				$user = Get-ADUser -Filter ('Name -like "*{0}*"' -f $current)
				Write-Verbose -Message "Identified '$current' as $user"
				$queue.Enqueue($user.ToString())
				continue
			}

			Write-Verbose -Message "[PROCESS] Account: $current (Recursive:$Recurse)"
			$user = Get-ADUser -Identity $current -Properties directReports

			$user.DirectReports | ForEach-Object -Process {
				$report = $_.ToString()

				try {
					Get-ADUser -Identity $report -Properties mail, manager `
					| Select-Object -Property Name, SamAccountName, Mail, @{ Name = "Manager"; Expression = { (Get-Aduser -identity $psitem.manager).samaccountname } }

					if ($Recurse) {
						$queue.Enqueue($report)
					}
				}
				catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
					if ($SuppressError) {
						Write-Verbose -Message "[ERROR SUPPRESSED] Cannot find entry for: $report"
					} else {
						throw
					}
				}
			}
		}
	}
	END
	{
		if ($shouldUnloadModule) {
			Remove-Module -Name ActiveDirectory -ErrorAction 'SilentlyContinue' -Verbose:$false | Out-Null
		}
	}
}

<#
# Find all direct user reporting to Test_director
Get-ADDirectReports -Identity Test_director

# Find all Indirect user reporting to Test_director
Get-ADDirectReports -Identity Test_director -Recurse
#>
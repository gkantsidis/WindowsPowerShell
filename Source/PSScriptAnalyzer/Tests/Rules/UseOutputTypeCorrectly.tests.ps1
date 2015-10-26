﻿Import-Module PSScriptAnalyzer
$violationMessage = "The cmdlet 'Verb-Files' returns an object of type 'System.Collections.Hashtable' but this type is not declared in the OutputType attribute."
$violationName = "PSUseOutputTypeCorrectly"
$directory = Split-Path -Parent $MyInvocation.MyCommand.Path
$violations = Invoke-ScriptAnalyzer $directory\BadCmdlet.ps1 | Where-Object {$_.RuleName -eq $violationName}
$dscViolations = Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue $directory\DSCResources\MyDscResource\MyDscResource.psm1 | Where-Object {$_.RuleName -eq $violationName}
$noViolations = Invoke-ScriptAnalyzer $directory\GoodCmdlet.ps1 | Where-Object {$_.RuleName -eq $violationName}

Describe "UseOutputTypeCorrectly" {
    Context "When there are violations" {
        It "has 2 Use OutputType Correctly violations" {
            $violations.Count | Should Be 2
        }

        It "has the correct description message" {
            $violations[0].Message | Should Match $violationMessage
        }
        
        It "Does not count violation in DSC class" {
            $dscViolations.Count | Should Be 0
        }
    }

    Context "When there are no violations" {
        It "returns no violations" {
            $noViolations.Count | Should Be 0
        }
    }
}
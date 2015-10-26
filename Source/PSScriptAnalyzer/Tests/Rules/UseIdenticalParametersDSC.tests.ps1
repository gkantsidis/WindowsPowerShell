﻿Import-Module PSScriptAnalyzer

$violationMessage = "The Test and Set-TargetResource functions of DSC Resource must have the same parameters."
$violationName = "PSDSCUseIdenticalParametersForDSC"
$directory = Split-Path -Parent $MyInvocation.MyCommand.Path
$violations = Invoke-ScriptAnalyzer $directory\DSCResources\MSFT_WaitForAll\MSFT_WaitForAll.psm1 | Where-Object {$_.RuleName -eq $violationName}
$noViolations = Invoke-ScriptAnalyzer $directory\DSCResources\MSFT_WaitForAny\MSFT_WaitForAny.psm1 | Where-Object {$_.RuleName -eq $violationName}
$noClassViolations = Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue $directory\DSCResources\MyDscResource\MyDscResource.psm1 | Where-Object {$_.RuleName -eq $violationName}

Describe "UseIdenticalParametersDSC" {
    Context "When there are violations" {
        It "has 1 Use Identical Parameters For DSC violations" {
            $violations.Count | Should Be 1
        }

        It "has the correct description message" {
            $violations[0].Message | Should Match $violationMessage
        }
    }

    Context "When there are no violations" {
        It "returns no violations" {
            $noViolations.Count | Should Be 0
        }

        It "returns no violations for DSC Classes" {
            $noClassViolations.Count | Should Be 0
        }
    }
}
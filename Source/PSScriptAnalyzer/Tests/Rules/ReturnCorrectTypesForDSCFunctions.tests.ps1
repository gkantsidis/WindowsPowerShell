﻿Import-Module -Verbose PSScriptAnalyzer

$violationMessageDSCResource = "Test-TargetResource function in DSC Resource should return object of type System.Boolean instead of System.Collections.Hashtable"
$violationMessageDSCClass = "Get function in DSC Class FileResource should return object of type FileResource instead of type System.Collections.Hashtable"
$violationName = "PSDSCReturnCorrectTypesForDSCFunctions"
$directory = Split-Path -Parent $MyInvocation.MyCommand.Path
$violations = Invoke-ScriptAnalyzer $directory\DSCResources\MSFT_WaitForAll\MSFT_WaitForAll.psm1 | Where-Object {$_.RuleName -eq $violationName}
$noViolations = Invoke-ScriptAnalyzer $directory\DSCResources\MSFT_WaitForAny\MSFT_WaitForAny.psm1 | Where-Object {$_.RuleName -eq $violationName}
$classViolations = Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue $directory\DSCResources\BadDscResource\BadDscResource.psm1 | Where-Object {$_.RuleName -eq $violationName}
$noClassViolations = Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue $directory\DSCResources\MyDscResource\MyDscResource.psm1 | Where-Object {$_.RuleName -eq $violationName}

Describe "ReturnCorrectTypesForDSCFunctions" {
    Context "When there are violations" {
        It "has 5 return correct types for DSC functions violations" {
            $violations.Count | Should Be 5
        }

        It "has the correct description message" {
            $violations[2].Message | Should Match $violationMessageDSCResource
        }
    }

    Context "When there are no violations" {
        It "returns no violations" {
            $noViolations.Count | Should Be 0
        }
    }
}

Describe "StandardDSCFunctionsInClass" {
    Context "When there are violations" {
        It "has 4 return correct types for DSC functions violations" {
            $classViolations.Count | Should Be 4
        }

        It "has the correct description message" {
            $classViolations[0].Message | Should Match $violationMessageDSCClass
        }
    }

    Context "When there are no violations" {
        It "returns no violations" {
            $noClassViolations.Count | Should Be 0
        }
    }
}
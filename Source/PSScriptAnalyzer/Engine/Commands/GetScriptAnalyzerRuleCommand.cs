﻿//
// Copyright (c) Microsoft Corporation.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

using System;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.Linq;
using System.Management.Automation;
using Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic;

namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Commands
{
    /// <summary>
    /// GetScriptAnalyzerRuleCommand: Cmdlet to list all the analyzer rule names and descriptions.
    /// </summary>
    [Cmdlet(VerbsCommon.Get, "ScriptAnalyzerRule", HelpUri = "http://go.microsoft.com/fwlink/?LinkId=525913")]
    public class GetScriptAnalyzerRuleCommand : PSCmdlet, IOutputWriter
    {
        #region Parameters
        /// <summary>
        /// Path: Path to custom rules folder.
        /// </summary>
        [Parameter(Mandatory = false)]
        [ValidateNotNullOrEmpty]
        [SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays")]
        public string[] CustomizedRulePath
        {
            get { return customizedRulePath; }
            set { customizedRulePath = value; }
        }
        private string[] customizedRulePath;

        /// <summary>
        /// Name: The name of a specific rule to list.
        /// </summary>
        [Parameter(Mandatory = false)]
        [ValidateNotNullOrEmpty]
        [SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays")]
        public string[] Name
        {
            get { return name; }
            set { name = value; }
        }
        private string[] name;

        /// <summary>
        /// Severity: Array of the severity types to be enabled.
        /// </summary>
        /// </summary>
        [ValidateSet("Warning", "Error", "Information", IgnoreCase = true)]
        [Parameter(Mandatory = false)]
        [SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays")]
        public string[] Severity
        {
            get { return severity; }
            set { severity = value; }
        }
        private string[] severity;

        #endregion Parameters

        #region Overrides

        /// <summary>
        /// BeginProcessing : TBD
        /// </summary>
        protected override void BeginProcessing()
        {
            ScriptAnalyzer.Instance.Initialize(this, customizedRulePath);
        }

        /// <summary>
        /// ProcessRecord : TBD
        /// </summary>
        protected override void ProcessRecord()
        {
            string[] modNames = ScriptAnalyzer.Instance.GetValidModulePaths();

            IEnumerable<IRule> rules = ScriptAnalyzer.Instance.GetRule(modNames, name);
            if (rules == null)
            {
                WriteObject(string.Format(CultureInfo.CurrentCulture, Strings.RulesNotFound));
            }
            else
            {
                if (severity != null)
                {
                    var ruleSeverity = severity.Select(item => Enum.Parse(typeof (RuleSeverity), item, true));
                    rules = rules.Where(item => ruleSeverity.Contains(item.GetSeverity())).ToList();
                }

                foreach (IRule rule in rules)
                {
                    WriteObject(new RuleInfo(rule.GetName(), rule.GetCommonName(), rule.GetDescription(),
                        rule.GetSourceType(), rule.GetSourceName(), rule.GetSeverity()));
                }
            }
        }

        #endregion
    }
}

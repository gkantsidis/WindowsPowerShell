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
using System.Linq;
using System.Management.Automation.Language;
using Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic;
using System.ComponentModel.Composition;
using System.Globalization;
using System.Management.Automation;

namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.BuiltinRules
{
    /// <summary>
    /// ProvideVerboseMessage: Analyzes the ast to check that Write-Verbose is called for DSC Resources
    /// </summary>
    [Export(typeof(IDSCResourceRule))]
    public class UseVerboseMessageInDSCResource : SkipNamedBlock, IDSCResourceRule
    {
        /// <summary>
        /// AnalyzeDSCResource: Analyzes the ast to check that Write-Verbose is called for DSC Resources
        /// <param name="ast">The script's ast</param>
        /// <param name="fileName">The script's file name</param>
        /// </summary>
        public IEnumerable<DiagnosticRecord> AnalyzeDSCResource(Ast ast, string fileName)
        {
            if (ast == null)
            {
                throw new ArgumentNullException(Strings.NullAstErrorMessage);
            }            

            IEnumerable<Ast> functionDefinitionAsts = Helper.Instance.DscResourceFunctions(ast);

            foreach (FunctionDefinitionAst functionDefinitionAst in functionDefinitionAsts)
            {
                var commandAsts = functionDefinitionAst.Body.FindAll(testAst => testAst is CommandAst, false);
                bool hasVerbose = false;

                if (null != commandAsts)
                {
                    foreach (CommandAst commandAst in commandAsts)
                    {
                        hasVerbose |= String.Equals(commandAst.GetCommandName(), "Write-Verbose", StringComparison.OrdinalIgnoreCase);
                    }
                }

                if (!hasVerbose)
                {
                    yield return new DiagnosticRecord(string.Format(CultureInfo.CurrentCulture, Strings.UseVerboseMessageInDSCResourceErrorFunction, functionDefinitionAst.Name),
                        functionDefinitionAst.Extent, GetName(), DiagnosticSeverity.Information, fileName);
                }

            }
        }
        
        /// <summary>
        /// AnalyzeDSCClass: This function returns nothing in the case of dsc class.
        /// </summary>
        /// <param name="ast"></param>
        /// <param name="fileName"></param>
        /// <returns></returns>
        public IEnumerable<DiagnosticRecord> AnalyzeDSCClass(Ast ast, string fileName)
        {
            return Enumerable.Empty<DiagnosticRecord>();
        }

        /// <summary>
        /// Method: Retrieves the name of this rule.
        /// </summary>
        public string GetName()
        {
            return string.Format(CultureInfo.CurrentCulture, Strings.NameSpaceFormat, GetSourceName(), Strings.UseVerboseMessageInDSCResourceName);
        }

        /// <summary>
        /// GetCommonName: Retrieves the common name of this rule.
        /// </summary>
        /// <returns>The common name of this rule</returns>
        public string GetCommonName()
        {
            return string.Format(CultureInfo.CurrentCulture, Strings.UseVerboseMessageInDSCResourceCommonName);
        }

        /// <summary>
        /// Method: Retrieves the description of this rule.
        /// </summary>
        /// <returns>The description of this rule</returns>
        public string GetDescription()
        {
            return string.Format(CultureInfo.CurrentCulture, Strings.UseVerboseMessageInDSCResourceDescription);
        }

        /// <summary>
        /// Method: Retrieves the type of the rule: builtin, managed or module.
        /// </summary>
        public SourceType GetSourceType()
        {
            return SourceType.Builtin;
        }

        /// <summary>
        /// GetSeverity: Retrieves the severity of the rule: error, warning of information.
        /// </summary>
        /// <returns></returns>
        public RuleSeverity GetSeverity()
        {
            return RuleSeverity.Information;
        }

        /// <summary>
        /// Method: Retrieves the module/assembly name the rule is from.
        /// </summary>
        public string GetSourceName()
        {
            return string.Format(CultureInfo.CurrentCulture, Strings.DSCSourceName);
        }
    }
}
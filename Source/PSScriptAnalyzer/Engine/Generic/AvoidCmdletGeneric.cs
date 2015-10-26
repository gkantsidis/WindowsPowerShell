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

namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
{
    /// <summary>
    /// Represents an abstract class for rule that checks whether the script
    /// uses certain cmdlet.
    /// </summary>
    public abstract class AvoidCmdletGeneric : IScriptRule
    {
        /// <summary>
        /// AnalyzeScript: Analyzes the given Ast and returns DiagnosticRecords based on the anaylsis.
        /// </summary>
        /// <param name="ast">The script's ast</param>
        /// <param name="fileName">The name of the script file being analyzed</param>
        /// <returns>The results of the analysis</returns>
        public IEnumerable<DiagnosticRecord> AnalyzeScript(Ast ast, string fileName)
        {
            if (ast == null) throw new ArgumentNullException("ast");

            // Finds all CommandAsts.
            IEnumerable<Ast> commandAsts = ast.FindAll(testAst => testAst is CommandAst, true);

            List<String> cmdletNameAndAliases = Microsoft.Windows.PowerShell.ScriptAnalyzer.Helper.Instance.CmdletNameAndAliases(GetCmdletName());

            // Iterrates all CommandAsts and check the command name.
            foreach (CommandAst cmdAst in commandAsts)
            {
                if (cmdAst.GetCommandName() == null) continue;

                if (cmdletNameAndAliases.Contains(cmdAst.GetCommandName(), StringComparer.OrdinalIgnoreCase))
                {
                    yield return new DiagnosticRecord(GetError(fileName), cmdAst.Extent, GetName(), DiagnosticSeverity.Warning, fileName);
                }
            }
        }

        /// <summary>
        /// Retrieves the name of the cmdlet to avoid
        /// </summary>
        /// <returns></returns>
        public abstract string GetCmdletName();

        /// <summary>
        /// GetError: Retrieves the error message.
        /// </summary>
        /// <returns></returns>
        public abstract string GetError(string FileName);

        /// <summary>
        /// GetName: Retrieves the name of the rule.
        /// </summary>
        /// <returns>The name of the rule.</returns>
        public abstract string GetName();

        /// <summary>
        /// GetCommonName: Retrieves the common name of this rule.
        /// </summary>
        /// <returns>The common name of this rule</returns>
        public abstract string GetCommonName();

        /// <summary>
        /// GetDescription: Retrieves the description of the rule.
        /// </summary>
        /// <returns>The description of the rule.</returns>
        public abstract string GetDescription();

        /// <summary>
        /// GetSourceName: Retrieves the source name of the rule.
        /// </summary>
        /// <returns>The source name of the rule.</returns>
        public abstract string GetSourceName();

        /// <summary>
        /// GetSourceType: Retrieves the source type of the rule.
        /// </summary>
        /// <returns>The source type of the rule.</returns>
        public abstract  SourceType GetSourceType();

        /// <summary>
        /// GetSeverity: Retrieves the severity of the rule: error, warning of information.
        /// </summary>
        /// <returns></returns>
        public abstract RuleSeverity GetSeverity();
    }
}

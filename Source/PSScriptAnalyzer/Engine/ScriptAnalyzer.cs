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

using System.Text.RegularExpressions;
using Microsoft.Windows.PowerShell.ScriptAnalyzer.Commands;
using Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic;
using System;
using System.Collections.Generic;
using System.ComponentModel.Composition;
using System.ComponentModel.Composition.Hosting;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Globalization;
using System.Collections.Concurrent;
using System.Threading.Tasks;

namespace Microsoft.Windows.PowerShell.ScriptAnalyzer
{
    public sealed class ScriptAnalyzer
    {
        #region Private members

        private IOutputWriter outputWriter;
        private CompositionContainer container;
        Dictionary<string, List<string>> validationResults = new Dictionary<string, List<string>>();
        string[] includeRule;
        string[] excludeRule;
        string[] severity;
        List<Regex> includeRegexList;
        List<Regex> excludeRegexList;
        bool suppressedOnly;

        #endregion

        #region Singleton
        private static object syncRoot = new Object();

        private static ScriptAnalyzer instance;

        public static ScriptAnalyzer Instance
        {
            get
            {
                if (instance == null)
                {
                    lock (syncRoot)
                    {
                        if (instance == null)
                            instance = new ScriptAnalyzer();
                    }
                }

                return instance;
            }
        }

        #endregion

        #region Properties

        // Initializes via ImportMany
        [ImportMany]
        public IEnumerable<IScriptRule> ScriptRules { get; private set; }

        [ImportMany]
        public IEnumerable<ITokenRule> TokenRules { get; private set; }

        [ImportMany]
        public IEnumerable<ILogger> Loggers { get; private set; }

        [ImportMany]
        public IEnumerable<IDSCResourceRule> DSCResourceRules { get; private set; }

        internal List<ExternalRule> ExternalRules { get; set; }

        #endregion

        #region Methods

        /// <summary>
        /// Initialize : Initializes default rules, loggers and helper.
        /// </summary>
        internal void Initialize<TCmdlet>(
            TCmdlet cmdlet, 
            string[] customizedRulePath = null,
            string[] includeRuleNames = null, 
            string[] excludeRuleNames = null,
            string[] severity = null,
            bool suppressedOnly = false,
            string profile = null)
            where TCmdlet : PSCmdlet, IOutputWriter
        {
            if (cmdlet == null)
            {
                throw new ArgumentNullException("cmdlet");
            }

            this.Initialize(
                cmdlet,
                cmdlet.SessionState.Path,
                cmdlet.SessionState.InvokeCommand,
                customizedRulePath,
                includeRuleNames,
                excludeRuleNames,
                severity,
                suppressedOnly,
                profile);
        }

        /// <summary>
        /// Initialize : Initializes default rules, loggers and helper.
        /// </summary>
        public void Initialize(
            Runspace runspace, 
            IOutputWriter outputWriter, 
            string[] customizedRulePath = null, 
            string[] includeRuleNames = null, 
            string[] excludeRuleNames = null,
            string[] severity = null,
            bool suppressedOnly = false,
            string profile = null)
        {
            if (runspace == null)
            {
                throw new ArgumentNullException("runspace");
            }

            this.Initialize(
                outputWriter,
                runspace.SessionStateProxy.Path,
                runspace.SessionStateProxy.InvokeCommand,
                customizedRulePath,
                includeRuleNames,
                excludeRuleNames,
                severity,
                suppressedOnly,
                profile);
        }

        private void Initialize(
            IOutputWriter outputWriter, 
            PathIntrinsics path, 
            CommandInvocationIntrinsics invokeCommand, 
            string[] customizedRulePath, 
            string[] includeRuleNames, 
            string[] excludeRuleNames,
            string[] severity,
            bool suppressedOnly = false,
            string profile = null)
        {
            if (outputWriter == null)
            {
                throw new ArgumentNullException("outputWriter");
            }

            this.outputWriter = outputWriter;

            #region Verifies rule extensions and loggers path

            List<string> paths = this.GetValidCustomRulePaths(customizedRulePath, path);

            #endregion

            #region Initializes Rules

            this.severity = severity;
            this.suppressedOnly = suppressedOnly;
            this.includeRule = includeRuleNames;
            this.excludeRule = excludeRuleNames;
            this.includeRegexList = new List<Regex>();
            this.excludeRegexList = new List<Regex>();

            if (!String.IsNullOrWhiteSpace(profile))
            {
                try
                {
                    profile = path.GetResolvedPSPathFromPSPath(profile).First().Path;
                }
                catch
                {
                    this.outputWriter.WriteError(new ErrorRecord(new FileNotFoundException(),
                        string.Format(CultureInfo.CurrentCulture, Strings.FileNotFound, profile),
                        ErrorCategory.InvalidArgument, this));
                }

                if (File.Exists(profile))
                {
                    Token[] parserTokens = null;
                    ParseError[] parserErrors = null;
                    Ast profileAst = Parser.ParseFile(profile, out parserTokens, out parserErrors);
                    IEnumerable<Ast> hashTableAsts = profileAst.FindAll(item => item is HashtableAst, false);
                    foreach (HashtableAst hashTableAst in hashTableAsts)
                    {
                        foreach (var kvp in hashTableAst.KeyValuePairs)
                        {
                            if (!(kvp.Item1 is StringConstantExpressionAst))
                            {
                                this.outputWriter.WriteError(new ErrorRecord(new ArgumentException(),
                                    string.Format(CultureInfo.CurrentCulture, Strings.WrongKeyFormat, kvp.Item1.Extent.StartLineNumber, kvp.Item1.Extent.StartColumnNumber, profile),
                                    ErrorCategory.InvalidArgument, this));
                                continue;
                            }

                            // parse the item2 as array
                            PipelineAst pipeAst = kvp.Item2 as PipelineAst;
                            List<string> rhsList = new List<string>();
                            if (pipeAst != null)
                            {
                                ExpressionAst pureExp = pipeAst.GetPureExpression();
                                if (pureExp is StringConstantExpressionAst)
                                {
                                    rhsList.Add((pureExp as StringConstantExpressionAst).Value);
                                }
                                else
                                {
                                    ArrayLiteralAst arrayLitAst = pureExp as ArrayLiteralAst;
                                    if (arrayLitAst == null && pureExp is ArrayExpressionAst)
                                    {
                                        ArrayExpressionAst arrayExp = pureExp as ArrayExpressionAst;
                                        // Statements property is never null
                                        if (arrayExp.SubExpression != null)
                                        {
                                            StatementAst stateAst = arrayExp.SubExpression.Statements.First();
                                            if (stateAst != null && stateAst is PipelineAst)
                                            {
                                                CommandBaseAst cmdBaseAst = (stateAst as PipelineAst).PipelineElements.First();
                                                if (cmdBaseAst != null && cmdBaseAst is CommandExpressionAst)
                                                {
                                                    CommandExpressionAst cmdExpAst = cmdBaseAst as CommandExpressionAst;
                                                    if (cmdExpAst.Expression is StringConstantExpressionAst)
                                                    {
                                                        rhsList.Add((cmdExpAst.Expression as StringConstantExpressionAst).Value);
                                                    }
                                                    else
                                                    {
                                                        arrayLitAst = cmdExpAst.Expression as ArrayLiteralAst;
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    if (arrayLitAst != null)
                                    {
                                        foreach (var element in arrayLitAst.Elements)
                                        {
                                            if (!(element is StringConstantExpressionAst))
                                            {
                                                this.outputWriter.WriteError(new ErrorRecord(new ArgumentException(),
                                                    string.Format(CultureInfo.CurrentCulture, Strings.WrongValueFormat, element.Extent.StartLineNumber, element.Extent.StartColumnNumber, profile),
                                                    ErrorCategory.InvalidArgument, this));
                                                continue;
                                            }

                                            rhsList.Add((element as StringConstantExpressionAst).Value);
                                        }
                                    }
                                }
                            }

                            if (rhsList.Count == 0)
                            {
                                this.outputWriter.WriteError(new ErrorRecord(new ArgumentException(),
                                    string.Format(CultureInfo.CurrentCulture, Strings.WrongValueFormat, kvp.Item2.Extent.StartLineNumber, kvp.Item2.Extent.StartColumnNumber, profile),
                                    ErrorCategory.InvalidArgument, this));
                                break;
                            }

                            switch ((kvp.Item1 as StringConstantExpressionAst).Value.ToLower())
                            {
                                case "severity":
                                    if (this.severity == null)
                                    {
                                        this.severity = rhsList.ToArray();
                                    }
                                    else
                                    {
                                        this.severity = this.severity.Union(rhsList).ToArray();
                                    }
                                    break;
                                case "includerules":
                                    if (this.includeRule == null)
                                    {
                                        this.includeRule = rhsList.ToArray();
                                    }
                                    else
                                    {
                                        this.includeRule = this.includeRule.Union(rhsList).ToArray();
                                    }
                                    break;
                                case "excluderules":
                                    if (this.excludeRule == null)
                                    {
                                        this.excludeRule = rhsList.ToArray();
                                    }
                                    else
                                    {
                                        this.excludeRule = this.excludeRule.Union(rhsList).ToArray();
                                    }
                                    break;
                                default:
                                    this.outputWriter.WriteError(new ErrorRecord(new ArgumentException(),
                                        string.Format(CultureInfo.CurrentCulture, Strings.WrongKey, kvp.Item1.Extent.StartLineNumber, kvp.Item1.Extent.StartColumnNumber, profile),
                                        ErrorCategory.InvalidArgument, this));
                                    break;
                            }
                        }
                    }
                }
            }

            //Check wild card input for the Include/ExcludeRules and create regex match patterns
            if (this.includeRule != null)
            {
                foreach (string rule in includeRule)
                {
                    Regex includeRegex = new Regex(String.Format("^{0}$", Regex.Escape(rule).Replace(@"\*", ".*")), RegexOptions.IgnoreCase);
                    this.includeRegexList.Add(includeRegex);
                }
            }
            if (this.excludeRule != null)
            {
                foreach (string rule in excludeRule)
                {
                    Regex excludeRegex = new Regex(String.Format("^{0}$", Regex.Escape(rule).Replace(@"\*", ".*")), RegexOptions.IgnoreCase);
                    this.excludeRegexList.Add(excludeRegex);
                }
            }

            try
            {
                this.LoadRules(this.validationResults, invokeCommand);
            }
            catch (Exception ex)
            {
                this.outputWriter.ThrowTerminatingError(
                    new ErrorRecord(
                        ex, 
                        ex.HResult.ToString("X", CultureInfo.CurrentCulture),
                        ErrorCategory.NotSpecified, this));
            }

            #endregion

            #region Verify rules

            // Safely get one non-duplicated list of rules
            IEnumerable<IRule> rules =
                Enumerable.Union<IRule>(
                    Enumerable.Union<IRule>(
                        this.ScriptRules ?? Enumerable.Empty<IRule>(),
                        this.TokenRules ?? Enumerable.Empty<IRule>()),
                    this.ExternalRules ?? Enumerable.Empty<IExternalRule>());

            // Ensure that rules were actually loaded
            if (rules == null || rules.Any() == false)
            {
                this.outputWriter.ThrowTerminatingError(
                    new ErrorRecord(
                        new Exception(), 
                        string.Format(
                            CultureInfo.CurrentCulture, 
                            Strings.RulesNotFound), 
                        ErrorCategory.ResourceExists, 
                        this));
            }

            #endregion
        }

        private List<string> GetValidCustomRulePaths(string[] customizedRulePath, PathIntrinsics path)
        {
            List<string> paths = new List<string>();

            if (customizedRulePath != null)
            {
                paths.AddRange(
                    customizedRulePath.ToList());
            }

            if (paths.Count > 0)
            {
                this.validationResults = this.CheckRuleExtension(paths.ToArray(), path);
                foreach (string extension in this.validationResults["InvalidPaths"])
                {
                    this.outputWriter.WriteWarning(string.Format(CultureInfo.CurrentCulture, Strings.MissingRuleExtension, extension));
                }
            }
            else
            {
                this.validationResults = new Dictionary<string, List<string>>();
                this.validationResults.Add("InvalidPaths", new List<string>());
                this.validationResults.Add("ValidModPaths", new List<string>());
                this.validationResults.Add("ValidDllPaths", new List<string>());
            }

            return paths;
        }

        private void LoadRules(Dictionary<string, List<string>> result, CommandInvocationIntrinsics invokeCommand)
        {
            List<string> paths = new List<string>();

            // Initialize helper
            Helper.Instance = new Helper(invokeCommand, this.outputWriter);
            Helper.Instance.Initialize();

            // Clear external rules for each invoke.
            this.ScriptRules = null;
            this.TokenRules = null;
            this.ExternalRules = null;

            // An aggregate catalog that combines multiple catalogs.
            using (AggregateCatalog catalog = new AggregateCatalog())
            {
                // Adds all the parts found in the same directory.
                string dirName = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                catalog.Catalogs.Add(
                    new SafeDirectoryCatalog(
                        dirName,
                        this.outputWriter));

                // Adds user specified directory
                paths = result.ContainsKey("ValidDllPaths") ? result["ValidDllPaths"] : result["ValidPaths"];
                foreach (string path in paths)
                {
                    if (String.Equals(Path.GetExtension(path), ".dll", StringComparison.OrdinalIgnoreCase))
                    {
                        catalog.Catalogs.Add(new AssemblyCatalog(path));
                    }
                    else
                    {
                        catalog.Catalogs.Add(
                            new SafeDirectoryCatalog(
                                path,
                                this.outputWriter));
                    }
                }

                // Creates the CompositionContainer with the parts in the catalog.
                container = new CompositionContainer(catalog);

                // Fills the imports of this object.
                try
                {
                    container.ComposeParts(this);
                }
                catch (CompositionException compositionException)
                {
                    this.outputWriter.WriteWarning(compositionException.ToString());
                }
            }

            // Gets external rules.
            if (result.ContainsKey("ValidModPaths") && result["ValidModPaths"].Count > 0)
                ExternalRules = GetExternalRule(result["ValidModPaths"].ToArray());
        }

        internal string[] GetValidModulePaths()
        {
            List<string> validModulePaths = null;

            if (!this.validationResults.TryGetValue("ValidModPaths", out validModulePaths))
            {
                validModulePaths = new List<string>();
            }

            return validModulePaths.ToArray();
        }

        public IEnumerable<IRule> GetRule(string[] moduleNames, string[] ruleNames)
        {
            IEnumerable<IRule> results = null;
            IEnumerable<IExternalRule> externalRules = null;

            // Combines C# rules.
            IEnumerable<IRule> rules = ScriptRules.Union<IRule>(TokenRules)
                                                  .Union<IRule>(DSCResourceRules);

            // Gets PowerShell Rules.
            if (moduleNames != null)
            {
                externalRules = GetExternalRule(moduleNames);
                rules = rules.Union<IRule>(externalRules);
            }

            if (ruleNames != null)
            {
                //Check wild card input for -Name parameter and create regex match patterns
                List<Regex> regexList = new List<Regex>();
                foreach (string ruleName in ruleNames)
                {
                    Regex includeRegex = new Regex(String.Format("^{0}$", Regex.Escape(ruleName).Replace(@"\*", ".*")), RegexOptions.IgnoreCase);
                    regexList.Add(includeRegex);
                }

                results = from rule in rules
                          from regex in regexList
                          where regex.IsMatch(rule.GetName())
                          select rule;
            }
            else
            {
                results = rules;
            }

            return results;
        }

        private List<ExternalRule> GetExternalRule(string[] moduleNames)
        {
            List<ExternalRule> rules = new List<ExternalRule>();

            if (moduleNames == null) return rules;

            // Converts module path to module name.
            foreach (string moduleName in moduleNames)
            {
                string shortModuleName = string.Empty;

                // Imports modules by using full path.
                InitialSessionState state = InitialSessionState.CreateDefault2();
                state.ImportPSModule(new string[] { moduleName });

                using (System.Management.Automation.PowerShell posh =
                       System.Management.Automation.PowerShell.Create(state))
                {
                    string script = string.Format(CultureInfo.CurrentCulture, "Get-Module -Name '{0}' -ListAvailable", moduleName);
                    shortModuleName = posh.AddScript(script).Invoke<PSModuleInfo>().First().Name;

                    // Invokes Update-Help for this module
                    // Required since when invoking Get-Help later on, the cmdlet prompts for Update-Help interactively
                    // By invoking Update-Help first, Get-Help will not prompt for downloading help later
                    script = string.Format(CultureInfo.CurrentCulture, "Update-Help -Module '{0}' -Force", shortModuleName);
                    posh.AddScript(script).Invoke();

                    // Invokes Get-Command and Get-Help for each functions in the module.
                    script = string.Format(CultureInfo.CurrentCulture, "Get-Command -Module '{0}'", shortModuleName);
                    var psobjects = posh.AddScript(script).Invoke();

                    foreach (PSObject psobject in psobjects)
                    {
                        posh.Commands.Clear();

                        FunctionInfo funcInfo = (FunctionInfo)psobject.ImmediateBaseObject;
                        ParameterMetadata param = funcInfo.Parameters.Values
                            .First<ParameterMetadata>(item => item.Name.EndsWith("ast", StringComparison.OrdinalIgnoreCase) ||
                                item.Name.EndsWith("token", StringComparison.OrdinalIgnoreCase));

                        //Only add functions that are defined as rules.
                        if (param != null)
                        {
                            script = string.Format(CultureInfo.CurrentCulture, "(Get-Help -Name {0}).Description | Out-String", funcInfo.Name);
                            string desc = posh.AddScript(script).Invoke()[0].ImmediateBaseObject.ToString()
                                    .Replace("\r\n", " ").Trim();

                            rules.Add(new ExternalRule(funcInfo.Name, funcInfo.Name, desc, param.Name, param.ParameterType.FullName,
                                funcInfo.ModuleName, funcInfo.Module.Path));
                        }
                    }
                }
            }

            return rules;
        }

        /// <summary>
        /// GetExternalRecord: Get external rules in parallel using RunspacePool and run each rule in its own runspace.
        /// </summary>
        /// <param name="ast"></param>
        /// <param name="token"></param>
        /// <param name="rules"></param>
        /// <param name="command"></param>
        /// <param name="filePath"></param>
        /// <returns></returns>
        internal IEnumerable<DiagnosticRecord> GetExternalRecord(Ast ast, Token[] token, ExternalRule[] rules, string filePath)
        {
            // Defines InitialSessionState.
            InitialSessionState state = InitialSessionState.CreateDefault2();

            // Groups rules by module paths and imports them.
            Dictionary<string, List<ExternalRule>> modules = rules
                .GroupBy<ExternalRule, string>(item => item.GetFullModulePath())
                .ToDictionary(item => item.Key, item => item.ToList());
            state.ImportPSModule(modules.Keys.ToArray<string>());

            // Creates and opens RunspacePool
            RunspacePool rsp = RunspaceFactory.CreateRunspacePool(state);
            rsp.SetMinRunspaces(1);
            rsp.SetMaxRunspaces(5);
            rsp.Open();

            // Groups rules by AstType and Tokens.
            Dictionary<string, List<ExternalRule>> astRuleGroups = rules
                .Where<ExternalRule>(item => item.GetParameter().EndsWith("ast", StringComparison.OrdinalIgnoreCase))
                .GroupBy<ExternalRule, string>(item => item.GetParameterType())
                .ToDictionary(item => item.Key, item => item.ToList());

            Dictionary<string, List<ExternalRule>> tokenRuleGroups = rules
                .Where<ExternalRule>(item => item.GetParameter().EndsWith("token", StringComparison.OrdinalIgnoreCase))
                .GroupBy<ExternalRule, string>(item => item.GetParameterType())
                .ToDictionary(item => item.Key, item => item.ToList());

            using (rsp)
            {
                // Defines the commands to be run.
                List<System.Management.Automation.PowerShell> powerShellCommands
                    = new List<System.Management.Automation.PowerShell>();

                // Defines the command results.
                List<IAsyncResult> powerShellCommandResults = new List<IAsyncResult>();

                #region Builds and invokes commands list

                foreach (KeyValuePair<string, List<ExternalRule>> tokenRuleGroup in tokenRuleGroups)
                {
                    foreach (IExternalRule rule in tokenRuleGroup.Value)
                    {
                        System.Management.Automation.PowerShell posh =
                            System.Management.Automation.PowerShell.Create();
                        posh.RunspacePool = rsp;

                        // Adds command to run external analyzer rule, like
                        // Measure-CurlyBracket -ScriptBlockAst $ScriptBlockAst
                        // Adds module name (source name) to handle ducplicate function names in different modules.
                        string ruleName = string.Format("{0}\\{1}", rule.GetSourceName(), rule.GetName());
                        posh.Commands.AddCommand(ruleName);
                        posh.Commands.AddParameter(rule.GetParameter(), token);

                        // Merges results because external analyzer rules may throw exceptions.
                        posh.Commands.Commands[0].MergeMyResults(PipelineResultTypes.Error,
                            PipelineResultTypes.Output);

                        powerShellCommands.Add(posh);
                        powerShellCommandResults.Add(posh.BeginInvoke());
                    }
                }

                foreach (KeyValuePair<string, List<ExternalRule>> astRuleGroup in astRuleGroups)
                {
                    // Find all AstTypes that appeared in rule groups.
                    IEnumerable<Ast> childAsts = ast.FindAll(new Func<Ast, bool>((testAst) =>
                        (astRuleGroup.Key.IndexOf(testAst.GetType().FullName, StringComparison.OrdinalIgnoreCase) != -1)), false);

                    foreach (Ast childAst in childAsts)
                    {
                        foreach (IExternalRule rule in astRuleGroup.Value)
                        {
                            System.Management.Automation.PowerShell posh =
                                System.Management.Automation.PowerShell.Create();
                            posh.RunspacePool = rsp;

                            // Adds command to run external analyzer rule, like
                            // Measure-CurlyBracket -ScriptBlockAst $ScriptBlockAst
                            // Adds module name (source name) to handle ducplicate function names in different modules.
                            string ruleName = string.Format("{0}\\{1}", rule.GetSourceName(), rule.GetName());
                            posh.Commands.AddCommand(ruleName);
                            posh.Commands.AddParameter(rule.GetParameter(), childAst);

                            // Merges results because external analyzer rules may throw exceptions.
                            posh.Commands.Commands[0].MergeMyResults(PipelineResultTypes.Error,
                                PipelineResultTypes.Output);

                            powerShellCommands.Add(posh);
                            powerShellCommandResults.Add(posh.BeginInvoke());
                        }
                    }
                }

                #endregion
                #region Collects the results from commands.
                List<DiagnosticRecord> diagnostics = new List<DiagnosticRecord>();
                try
                {
                    for (int i = 0; i < powerShellCommands.Count; i++)
                    {
                        // EndInvoke will wait for each command to finish, so we will be getting the commands
                        // in the same order that they have been invoked withy BeginInvoke.
                        PSDataCollection<PSObject> psobjects = powerShellCommands[i].EndInvoke(powerShellCommandResults[i]);

                        foreach (var psobject in psobjects)
                        {
                            DiagnosticSeverity severity;
                            IScriptExtent extent;
                            string message = string.Empty;
                            string ruleName = string.Empty;

                            if (psobject != null && psobject.ImmediateBaseObject != null)
                            {
                                // Because error stream is merged to output stream,
                                // we need to handle the error records.
                                if (psobject.ImmediateBaseObject is ErrorRecord)
                                {
                                    ErrorRecord record = (ErrorRecord)psobject.ImmediateBaseObject;
                                    this.outputWriter.WriteError(record);
                                    continue;
                                }

                                // DiagnosticRecord may not be correctly returned from external rule.
                                try
                                {
                                    Enum.TryParse<DiagnosticSeverity>(psobject.Properties["Severity"].Value.ToString().ToUpper(), out severity);
                                    message = psobject.Properties["Message"].Value.ToString();
                                    extent = (IScriptExtent)psobject.Properties["Extent"].Value;
                                    ruleName = psobject.Properties["RuleName"].Value.ToString();
                                }
                                catch (Exception ex)
                                {
                                    this.outputWriter.WriteError(new ErrorRecord(ex, ex.HResult.ToString("X"), ErrorCategory.NotSpecified, this));
                                    continue;
                                }

                                if (!string.IsNullOrEmpty(message))
                                {
                                    diagnostics.Add(new DiagnosticRecord(message, extent, ruleName, severity, null));
                                }
                            }
                        }
                    }
                }
                //Catch exception where customized defined rules have exceptins when doing invoke
                catch (Exception ex)
                {
                    this.outputWriter.WriteError(new ErrorRecord(ex, ex.HResult.ToString("X"), ErrorCategory.NotSpecified, this));
                }

                return diagnostics;
                #endregion
            }
        }

        public Dictionary<string, List<string>> CheckRuleExtension(string[] path, PathIntrinsics basePath)
        {
            Dictionary<string, List<string>> results = new Dictionary<string, List<string>>();

            List<string> invalidPaths = new List<string>();
            List<string> validDllPaths = new List<string>();
            List<string> validModPaths = new List<string>();

            // Gets valid module names
            foreach (string childPath in path)
            {
                try
                {
                    this.outputWriter.WriteVerbose(string.Format(CultureInfo.CurrentCulture, Strings.CheckModuleName, childPath));

                    string resolvedPath = string.Empty;

                    // Users may provide a valid module path or name, 
                    // We have to identify the childPath is really a directory or just a module name.
                    // You can also consider following two commands.
                    //   Get-ScriptAnalyzerRule -RuleExtension "ContosoAnalyzerRules"
                    //   Get-ScriptAnalyzerRule -RuleExtension "%USERPROFILE%\WindowsPowerShell\Modules\ContosoAnalyzerRules"
                    if (Path.GetDirectoryName(childPath) == string.Empty)
                    {
                        resolvedPath = childPath;
                    }
                    else
                    {
                        resolvedPath = basePath
                            .GetResolvedPSPathFromPSPath(childPath).First().ToString();
                    }

                    using (System.Management.Automation.PowerShell posh =
                           System.Management.Automation.PowerShell.Create())
                    {
                        string script = string.Format(CultureInfo.CurrentCulture, "Get-Module -Name '{0}' -ListAvailable", resolvedPath);
                        PSModuleInfo moduleInfo = posh.AddScript(script).Invoke<PSModuleInfo>().First();

                        // Adds original path, otherwise path.Except<string>(validModPaths) will fail.
                        // It's possible that user can provide something like this:
                        // "..\..\..\ScriptAnalyzer.UnitTest\modules\CommunityAnalyzerRules\CommunityAnalyzerRules.psd1"
                        if (moduleInfo.ExportedFunctions.Count > 0) validModPaths.Add(childPath);
                    }
                }
                catch
                {
                    // User may provide an invalid module name, like c:\temp.
                    // It's a invalid name for a Windows PowerShell module,
                    // But we need test it further since we allow user to provide a folder to extend rules.
                    // You can also consider following two commands.
                    //   Get-ScriptAnalyzerRule -RuleExtension "ContosoAnalyzerRules", "C:\Temp\ExtendScriptAnalyzerRules.dll"
                    //   Get-ScriptAnalyzerRule -RuleExtension "ContosoAnalyzerRules", "C:\Temp\"
                    continue;
                }
            }

            // Gets valid dll paths
            foreach (string childPath in path.Except<string>(validModPaths))
            {
                try
                {
                    string resolvedPath = basePath
                        .GetResolvedPSPathFromPSPath(childPath).First().ToString();

                    this.outputWriter.WriteDebug(string.Format(CultureInfo.CurrentCulture, Strings.CheckAssemblyFile, resolvedPath));

                    if (String.Equals(Path.GetExtension(resolvedPath), ".dll", StringComparison.OrdinalIgnoreCase))
                    {
                        if (!File.Exists(resolvedPath))
                        {
                            invalidPaths.Add(resolvedPath);
                            continue;
                        }
                    }
                    else
                    {
                        if (!Directory.Exists(resolvedPath))
                        {
                            invalidPaths.Add(resolvedPath);
                            continue;
                        }
                    }

                    validDllPaths.Add(resolvedPath);
                }
                catch
                {
                    invalidPaths.Add(childPath);
                }
            }

            // Resloves relative paths.
            try
            {
                for (int i = 0; i < validModPaths.Count; i++)
                {
                    validModPaths[i] = basePath
                        .GetResolvedPSPathFromPSPath(validModPaths[i]).First().ToString();
                }
                for (int i = 0; i < validDllPaths.Count; i++)
                {
                    validDllPaths[i] = basePath
                        .GetResolvedPSPathFromPSPath(validDllPaths[i]).First().ToString();
                }
            }
            catch
            {
                // If GetResolvedPSPathFromPSPath failed. We can safely ignore the exception.
                // Because GetResolvedPSPathFromPSPath always fails when trying to resolve a module name.
            }

            // Returns valid rule extensions
            results.Add("InvalidPaths", invalidPaths);
            results.Add("ValidModPaths", validModPaths);
            results.Add("ValidDllPaths", validDllPaths);

            return results;
        }

        #endregion


        /// <summary>
        /// Analyzes a script file or a directory containing script files.
        /// </summary>
        /// <param name="path">The path of the file or directory to analyze.</param>
        /// <param name="searchRecursively">
        /// If true, recursively searches the given file path and analyzes any 
        /// script files that are found.
        /// </param>
        /// <returns>An enumeration of DiagnosticRecords that were found by rules.</returns>
        public IEnumerable<DiagnosticRecord> AnalyzePath(string path, bool searchRecursively = false)
        {
            List<string> scriptFilePaths = new List<string>();

            if (path == null)
            {
                this.outputWriter.ThrowTerminatingError(
                    new ErrorRecord(
                        new FileNotFoundException(),
                        string.Format(CultureInfo.CurrentCulture, Strings.FileNotFound, path),
                        ErrorCategory.InvalidArgument, 
                        this));
            }

            // Precreate the list of script file paths to analyze.  This
            // is an optimization over doing the whole operation at once
            // and calling .Concat on IEnumerables to join results.
            this.BuildScriptPathList(path, searchRecursively, scriptFilePaths);

            foreach (string scriptFilePath in scriptFilePaths)
            {
                // Yield each record in the result so that the 
                // caller can pull them one at a time
                foreach (var diagnosticRecord in this.AnalyzeFile(scriptFilePath))
                {
                    yield return diagnosticRecord;
                }
            }
        }

        private void BuildScriptPathList(
            string path, 
            bool searchRecursively, 
            IList<string> scriptFilePaths)
        {
            const string ps1Suffix = ".ps1";
            const string psm1Suffix = ".psm1";
            const string psd1Suffix = ".psd1";

            if (Directory.Exists(path))
            {
                if (searchRecursively)
                {
                    foreach (string filePath in Directory.GetFiles(path))
                    {
                        this.BuildScriptPathList(filePath, searchRecursively, scriptFilePaths);
                    }
                    foreach (string filePath in Directory.GetDirectories(path))
                    {
                        this.BuildScriptPathList(filePath, searchRecursively, scriptFilePaths);
                    }
                }
                else
                {
                    foreach (string filePath in Directory.GetFiles(path))
                    {
                        this.BuildScriptPathList(filePath, searchRecursively, scriptFilePaths);
                    }
                }
            }
            else if (File.Exists(path))
            {
                String fileName = Path.GetFileName(path);
                if ((fileName.Length > ps1Suffix.Length && String.Equals(Path.GetExtension(path), ps1Suffix, StringComparison.OrdinalIgnoreCase)) ||
                    (fileName.Length > psm1Suffix.Length && String.Equals(Path.GetExtension(path), psm1Suffix, StringComparison.OrdinalIgnoreCase)) ||
                    (fileName.Length > psd1Suffix.Length && String.Equals(Path.GetExtension(path), psd1Suffix, StringComparison.OrdinalIgnoreCase)))
                {
                    scriptFilePaths.Add(path);
                }
                else if (Helper.Instance.IsHelpFile(path))
                {
                    scriptFilePaths.Add(path);
                }
            }
            else
            {
                this.outputWriter.WriteError(
                    new ErrorRecord(
                        new FileNotFoundException(), 
                        string.Format(CultureInfo.CurrentCulture, Strings.FileNotFound, path), 
                        ErrorCategory.InvalidArgument, 
                        this));
            }
        }

        private IEnumerable<DiagnosticRecord> AnalyzeFile(string filePath)
        {
            ScriptBlockAst scriptAst = null;
            Token[] scriptTokens = null;
            ParseError[] errors = null;

            this.outputWriter.WriteVerbose(string.Format(CultureInfo.CurrentCulture, Strings.VerboseFileMessage, filePath));

            //Parse the file
            if (File.Exists(filePath))
            {
                // processing for non help script
                if (!(Path.GetFileName(filePath).StartsWith("about_") && Path.GetFileName(filePath).EndsWith(".help.txt")))
                {
                    try
                    {
                        scriptAst = Parser.ParseFile(filePath, out scriptTokens, out errors);
                    }
                    catch (Exception e)
                    {
                        this.outputWriter.WriteWarning(e.ToString());
                        return null;
                    }

                    if (errors != null && errors.Length > 0)
                    {
                        foreach (ParseError error in errors)
                        {
                            string parseErrorMessage = String.Format(CultureInfo.CurrentCulture, Strings.ParserErrorFormat, error.Extent.File, error.Message.TrimEnd('.'), error.Extent.StartLineNumber, error.Extent.StartColumnNumber);
                            this.outputWriter.WriteError(new ErrorRecord(new ParseException(parseErrorMessage), parseErrorMessage, ErrorCategory.ParserError, error.ErrorId));
                        }
                    }

                    if (errors != null && errors.Length > 10)
                    {
                        string manyParseErrorMessage = String.Format(CultureInfo.CurrentCulture, Strings.ParserErrorMessage, System.IO.Path.GetFileName(filePath));
                        this.outputWriter.WriteError(new ErrorRecord(new ParseException(manyParseErrorMessage), manyParseErrorMessage, ErrorCategory.ParserError, filePath));

                        return new List<DiagnosticRecord>();
                    }
                }
            }
            else
            {
                this.outputWriter.ThrowTerminatingError(new ErrorRecord(new FileNotFoundException(),
                    string.Format(CultureInfo.CurrentCulture, Strings.InvalidPath, filePath),
                    ErrorCategory.InvalidArgument, filePath));

                return null;
            }

            return this.AnalyzeSyntaxTree(scriptAst, scriptTokens, filePath);
        }

        /// <summary>
        /// Analyzes the syntax tree of a script file that has already been parsed.
        /// </summary>
        /// <param name="scriptAst">The ScriptBlockAst from the parsed script.</param>
        /// <param name="scriptTokens">The tokens found in the script.</param>
        /// <param name="filePath">The path to the file that was parsed.</param>
        /// <returns>An enumeration of DiagnosticRecords that were found by rules.</returns>
        public IEnumerable<DiagnosticRecord> AnalyzeSyntaxTree(
            ScriptBlockAst scriptAst, 
            Token[] scriptTokens, 
            string filePath)
        {
            Dictionary<string, List<RuleSuppression>> ruleSuppressions = new Dictionary<string,List<RuleSuppression>>();
            ConcurrentBag<DiagnosticRecord> diagnostics = new ConcurrentBag<DiagnosticRecord>();
            ConcurrentBag<SuppressedRecord> suppressed = new ConcurrentBag<SuppressedRecord>();
            BlockingCollection<List<object>> verboseOrErrors = new BlockingCollection<List<object>>();

            // Use a List of KVP rather than dictionary, since for a script containing inline functions with same signature, keys clash
            List<KeyValuePair<CommandInfo, IScriptExtent>> cmdInfoTable = new List<KeyValuePair<CommandInfo, IScriptExtent>>();

            bool helpFile = (scriptAst == null) && Helper.Instance.IsHelpFile(filePath);

            if (!helpFile)
            {
                ruleSuppressions = Helper.Instance.GetRuleSuppression(scriptAst);

                foreach (List<RuleSuppression> ruleSuppressionsList in ruleSuppressions.Values)
                {
                    foreach (RuleSuppression ruleSuppression in ruleSuppressionsList)
                    {
                        if (!String.IsNullOrWhiteSpace(ruleSuppression.Error))
                        {
                            this.outputWriter.WriteError(new ErrorRecord(new ArgumentException(ruleSuppression.Error), ruleSuppression.Error, ErrorCategory.InvalidArgument, ruleSuppression));
                        }
                    }
                }

                #region Run VariableAnalysis
                try
                {
                    Helper.Instance.InitializeVariableAnalysis(scriptAst);
                }
                catch { }
                #endregion

                Helper.Instance.Tokens = scriptTokens;
            }

            #region Run ScriptRules
            //Trim down to the leaf element of the filePath and pass it to Diagnostic Record
            string fileName = System.IO.Path.GetFileName(filePath);

            if (this.ScriptRules != null)
            {
                var tasks = this.ScriptRules.Select(scriptRule => Task.Factory.StartNew(() =>
                {
                    bool includeRegexMatch = false;
                    bool excludeRegexMatch = false;

                    foreach (Regex include in includeRegexList)
                    {
                        if (include.IsMatch(scriptRule.GetName()))
                        {
                            includeRegexMatch = true;
                            break;
                        }
                    }

                    foreach (Regex exclude in excludeRegexList)
                    {
                        if (exclude.IsMatch(scriptRule.GetName()))
                        {
                            excludeRegexMatch = true;
                            break;
                        }
                    }

                    bool helpRule = String.Equals(scriptRule.GetName(), "PSUseUTF8EncodingForHelpFile", StringComparison.OrdinalIgnoreCase);

                    if ((includeRule == null || includeRegexMatch) && (excludeRule == null || !excludeRegexMatch))
                    {
                        List<object> result = new List<object>();

                        result.Add(string.Format(CultureInfo.CurrentCulture, Strings.VerboseRunningMessage, scriptRule.GetName()));

                        // Ensure that any unhandled errors from Rules are converted to non-terminating errors
                        // We want the Engine to continue functioning even if one or more Rules throws an exception
                        try
                        {
                            if (helpRule && helpFile)
                            {
                                var records = scriptRule.AnalyzeScript(scriptAst, filePath);
                                foreach (var record in records)
                                {
                                    diagnostics.Add(record);
                                }
                            }
                            else if (!helpRule && !helpFile)
                            {
                                var records = Helper.Instance.SuppressRule(scriptRule.GetName(), ruleSuppressions, scriptRule.AnalyzeScript(scriptAst, scriptAst.Extent.File).ToList());
                                foreach (var record in records.Item2)
                                {
                                    diagnostics.Add(record);
                                }
                                foreach (var suppressedRec in records.Item1)
                                {
                                    suppressed.Add(suppressedRec);
                                }
                            }
                        }
                        catch (Exception scriptRuleException)
                        {
                            result.Add(new ErrorRecord(scriptRuleException, Strings.RuleErrorMessage, ErrorCategory.InvalidOperation, scriptAst.Extent.File));
                        }

                        verboseOrErrors.Add(result);
                    }
                }));

                Task.Factory.ContinueWhenAll(tasks.ToArray(), t => verboseOrErrors.CompleteAdding());

                while (!verboseOrErrors.IsCompleted)
                {
                    List<object> data = null;
                    try
                    {
                        data = verboseOrErrors.Take();
                    }
                    catch (InvalidOperationException) { }

                    if (data != null)
                    {
                        this.outputWriter.WriteVerbose(data[0] as string);
                        if (data.Count == 2)
                        {
                            this.outputWriter.WriteError(data[1] as ErrorRecord);
                        }
                    }
                }
            }

            #endregion

            #region Run Token Rules

            if (this.TokenRules != null && !helpFile)
            {
                foreach (ITokenRule tokenRule in this.TokenRules)
                {
                    bool includeRegexMatch = false;
                    bool excludeRegexMatch = false;
                    foreach (Regex include in includeRegexList)
                    {
                        if (include.IsMatch(tokenRule.GetName()))
                        {
                            includeRegexMatch = true;
                            break;
                        }
                    }
                    foreach (Regex exclude in excludeRegexList)
                    {
                        if (exclude.IsMatch(tokenRule.GetName()))
                        {
                            excludeRegexMatch = true;
                            break;
                        }
                    }
                    if ((includeRule == null || includeRegexMatch) && (excludeRule == null || !excludeRegexMatch))
                    {
                        this.outputWriter.WriteVerbose(string.Format(CultureInfo.CurrentCulture, Strings.VerboseRunningMessage, tokenRule.GetName()));

                        // Ensure that any unhandled errors from Rules are converted to non-terminating errors
                        // We want the Engine to continue functioning even if one or more Rules throws an exception
                        try
                        {
                            var records = Helper.Instance.SuppressRule(tokenRule.GetName(), ruleSuppressions, tokenRule.AnalyzeTokens(scriptTokens, filePath).ToList());
                            foreach (var record in records.Item2)
                            {
                                diagnostics.Add(record);
                            }
                            foreach (var suppressedRec in records.Item1)
                            {
                                suppressed.Add(suppressedRec);
                            }
                        }
                        catch (Exception tokenRuleException)
                        {
                            this.outputWriter.WriteError(new ErrorRecord(tokenRuleException, Strings.RuleErrorMessage, ErrorCategory.InvalidOperation, fileName));
                        }
                    }
                }
            }

            #endregion

            #region DSC Resource Rules
            if (this.DSCResourceRules != null && !helpFile)
            {
                // Invoke AnalyzeDSCClass only if the ast is a class based resource
                if (Helper.Instance.IsDscResourceClassBased(scriptAst))
                {
                    // Run DSC Class rule
                    foreach (IDSCResourceRule dscResourceRule in this.DSCResourceRules)
                    {
                        bool includeRegexMatch = false;
                        bool excludeRegexMatch = false;

                        foreach (Regex include in includeRegexList)
                        {
                            if (include.IsMatch(dscResourceRule.GetName()))
                            {
                                includeRegexMatch = true;
                                break;
                            }
                        }

                        foreach (Regex exclude in excludeRegexList)
                        {
                            if (exclude.IsMatch(dscResourceRule.GetName()))
                            {
                                excludeRegexMatch = true;
                                break;
                            }
                        }

                        if ((includeRule == null || includeRegexMatch) && (excludeRule == null || excludeRegexMatch))
                        {
                            this.outputWriter.WriteVerbose(string.Format(CultureInfo.CurrentCulture, Strings.VerboseRunningMessage, dscResourceRule.GetName()));

                            // Ensure that any unhandled errors from Rules are converted to non-terminating errors
                            // We want the Engine to continue functioning even if one or more Rules throws an exception
                            try
                            {
                                var records = Helper.Instance.SuppressRule(dscResourceRule.GetName(), ruleSuppressions, dscResourceRule.AnalyzeDSCClass(scriptAst, filePath).ToList());
                                foreach (var record in records.Item2)
                                {
                                    diagnostics.Add(record);
                                }
                                foreach (var suppressedRec in records.Item1)
                                {
                                    suppressed.Add(suppressedRec);
                                }
                            }
                            catch (Exception dscResourceRuleException)
                            {
                                this.outputWriter.WriteError(new ErrorRecord(dscResourceRuleException, Strings.RuleErrorMessage, ErrorCategory.InvalidOperation, filePath));
                            }
                        }
                    }
                }

                // Check if the supplied artifact is indeed part of the DSC resource
                if (Helper.Instance.IsDscResourceModule(filePath))
                {
                    // Run all DSC Rules
                    foreach (IDSCResourceRule dscResourceRule in this.DSCResourceRules)
                    {
                        bool includeRegexMatch = false;
                        bool excludeRegexMatch = false;
                        foreach (Regex include in includeRegexList)
                        {
                            if (include.IsMatch(dscResourceRule.GetName()))
                            {
                                includeRegexMatch = true;
                                break;
                            }
                        }
                        foreach (Regex exclude in excludeRegexList)
                        {
                            if (exclude.IsMatch(dscResourceRule.GetName()))
                            {
                                excludeRegexMatch = true;
                            }
                        }
                        if ((includeRule == null || includeRegexMatch) && (excludeRule == null || !excludeRegexMatch))
                        {
                            this.outputWriter.WriteVerbose(string.Format(CultureInfo.CurrentCulture, Strings.VerboseRunningMessage, dscResourceRule.GetName()));

                            // Ensure that any unhandled errors from Rules are converted to non-terminating errors
                            // We want the Engine to continue functioning even if one or more Rules throws an exception
                            try
                            {
                                var records = Helper.Instance.SuppressRule(dscResourceRule.GetName(), ruleSuppressions, dscResourceRule.AnalyzeDSCResource(scriptAst, filePath).ToList());
                                foreach (var record in records.Item2)
                                {
                                    diagnostics.Add(record);
                                }
                                foreach (var suppressedRec in records.Item1)
                                {
                                    suppressed.Add(suppressedRec);
                                }
                            }
                            catch (Exception dscResourceRuleException)
                            {
                                this.outputWriter.WriteError(new ErrorRecord(dscResourceRuleException, Strings.RuleErrorMessage, ErrorCategory.InvalidOperation, filePath));
                            }
                        }
                    }

                }
            }
            #endregion

            #region Run External Rules

            if (this.ExternalRules != null && !helpFile)
            {
                List<ExternalRule> exRules = new List<ExternalRule>();

                foreach (ExternalRule exRule in this.ExternalRules)
                {
                    if ((includeRule == null || includeRule.Contains(exRule.GetName(), StringComparer.OrdinalIgnoreCase)) &&
                        (excludeRule == null || !excludeRule.Contains(exRule.GetName(), StringComparer.OrdinalIgnoreCase)))
                    {
                        string ruleName = string.Format(CultureInfo.CurrentCulture, "{0}\\{1}", exRule.GetSourceName(), exRule.GetName());
                        this.outputWriter.WriteVerbose(string.Format(CultureInfo.CurrentCulture, Strings.VerboseRunningMessage, ruleName));

                        // Ensure that any unhandled errors from Rules are converted to non-terminating errors
                        // We want the Engine to continue functioning even if one or more Rules throws an exception
                        try
                        {
                            exRules.Add(exRule);
                        }
                        catch (Exception externalRuleException)
                        {
                            this.outputWriter.WriteError(new ErrorRecord(externalRuleException, Strings.RuleErrorMessage, ErrorCategory.InvalidOperation, fileName));
                        }
                    }
                }

                foreach (var record in this.GetExternalRecord(scriptAst, scriptTokens, exRules.ToArray(), fileName))
                {
                    diagnostics.Add(record);
                }
            }

            #endregion

            IEnumerable<DiagnosticRecord> diagnosticsList = diagnostics;

            if (severity != null)
            {
                var diagSeverity = severity.Select(item => Enum.Parse(typeof(DiagnosticSeverity), item, true));
                diagnosticsList = diagnostics.Where(item => diagSeverity.Contains(item.Severity));
            }

            return this.suppressedOnly ?
                suppressed.OfType<DiagnosticRecord>() :
                diagnosticsList;
        }
    }
}

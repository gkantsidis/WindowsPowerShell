# Various notes about VSCode modules

## PowerShellEditorServices

It is possible to see compilation errors. Sometimes it happens that the systems continuously tries
to download the dotnet framework. Assuming that you have a working version of `dotnet`, i.e.
the command `dotnet --version` should produce a valid answer, you may wish to make the following
changes to the file `PowerShellEditorServices.build.ps1`:

```[PowerShell]
+    $dotnetversion = & $dotnetExePath --version
+    if ($dotnetversion.Contains("-")) {
+        $dotnetversion = $dotnetversion.Substring(0, $dotnetversion.IndexOf("-"))
+    }
+
+    $requiredVersion = [Version]::Parse($requiredSdkVersion)
+    $currentVersion = [Version]::Parse($dotnetversion)
+    $isSdkVersionOk = ($requiredVersion.CompareTo($currentVersion)) -le 0
+
     # Make sure the dotnet we found is the right version
-    if ($dotnetExePath -and (& $dotnetExePath --version) -eq $requiredSdkVersion) {
+    if ($dotnetExePath -and $isSdkVersionOk) {
```

This is a more robust way to check the version.

One way to keep track of the change without changing the master is to make the change
in a branch (e.g. `flexible-dotnet`).

Sometimes it helps to build the following projects manually:

```[cmd]
dotnet build .\src\PowerShellEditorServices.Host\PowerShellEditorServices.Host.csproj
dotnet build .\src\PowerShellEditorServices.VSCode\PowerShellEditorServices.VSCode.csproj
```

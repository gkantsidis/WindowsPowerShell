
## WindowsPowerShell
This contains a customized Windows Powershell Profile

## Setup
This directory should be cloned under `%HOME%\Documents\WindowsPowerShell`
(e.g. `C:\users\\&lt;UserName&gt;\\Documents\WindowsPowerShell`).
After cloning, pull submodules with:
- `git submodule init` and
- `git submodule update`

Dependencies:
- [WiX Toolset](http://wixtoolset.org/), which is required for Pscx
Required for Pscx

You may consider to periodically update submodules with
```
git submodule foreach git pull origin master
```

## Startup
As part of the startup, the scripts check and load a number of useful modules.
Periodically, it will also check online for updates to those modules.
As a result it takes time to load; typically 10-20sec on a decent machine
(a bit longer if it checks for updates).
The first invocation will take much longer as it will try to check online for
updated versions of the modules.

For fast startup and no customizations, use:
```
powershell -NoProfile
```

## Startup problems
If it does not find a required module, the profile will not apply the related customizations,
but it will give a warning to install those modules. The warning will continue until the module
gets installed; otherwise, it should not be a problem.

The startup will also give warnings for outdated modules. Update them and the warnings will go away.

If you experience any other issue during startup, please create an [issue](https://github.com/gkantsidis/WindowsPowerShell/issues).
Do look in the [closed issues](https://github.com/gkantsidis/WindowsPowerShell/issues?q=is%3Aissue+is%3Aclosed) section
for answers to problems that have been solved.

## Powershell ISE
There is a separate customization for ISE. Some modules do not work well with ISE, and
they are not invoked.

# Per-machine customizations
Settings that are local to a machine, and do not need to be checked in should to to `profile_local.ps1`.
If this file is present, then it will be executed at the end of initialization.

# PowerShell 6.0 (with .NET Core) and PowerShell in Linux

I will try to make sure that the profile works also with the PS 6.0 (which uses .NET Core instead of .NET Framework), and 
that it also works in Linux. This is rather challenging, since I am pulling modules and code from various places and it is
difficult to check all combinations. Please report an [issue](https://github.com/gkantsidis/WindowsPowerShell/issues) if
you find any problems.

# Other information
See the [wiki](https://github.com/gkantsidis/WindowsPowerShell/wiki) for information
about the customizations.

Some general instructions for creating Windows PowerShell profiles:
https://technet.microsoft.com/en-us/library/hh847857.aspx


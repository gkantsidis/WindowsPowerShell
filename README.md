# WindowsPowerShell
Windows Powershell Profile

This directory should be cloned under %HOME%\Documents\WindowsPowerShell
(e.g. C:\users\<UserName>\Documents\WindowsPowerShell).
After cloning, pull submodules with:
- git submodule init and
- git submodule update.

Dependencies:
- WiX Toolset: http://wixtoolset.org/
Required for Pscx

Some general instructions for creating Windows PowerShell profiles:
https://technet.microsoft.com/en-us/library/hh847857.aspx

To periodically update submodules, you can also use:
git submodule foreach git pull origin master

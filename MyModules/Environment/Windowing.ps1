if ($null -ne $Env:LIB) {
    $newLIB = $Env:LIB -split ';' | Where-Object { ($_.Length -gt 0) -and (Test-Path -Path "$_") }
    $env:LIB = [string]::Join(';', $newLIB)
}

Add-Type -TypeDefinition @"
  using System;
  using System.Runtime.InteropServices;
  public class WindowingTricks {
     [DllImport("user32.dll")]
     [return: MarshalAs(UnmanagedType.Bool)]
     public static extern bool SetForegroundWindow(IntPtr hWnd);

     [DllImport("user32.dll")]
     public static extern IntPtr GetForegroundWindow();
  }
"@

Add-Type @"
  using System;
  using System.Runtime.InteropServices;
  public class WindowingTricks {
     [DllImport("user32.dll")]
     [return: MarshalAs(UnmanagedType.Bool)]
     public static extern bool SetForegroundWindow(IntPtr hWnd);
  }
"@
#!/usr/bin/env pwsh
# Test file browser focus issue

$ErrorActionPreference = "Stop"

# Start the app
$proc = Start-Process pwsh -ArgumentList "-File", "Start.ps1" -PassThru -RedirectStandardOutput "test-output.txt" -RedirectStandardError "test-error.txt"

# Wait for it to start
Start-Sleep -Seconds 2

# Send key "3" to go to file browser
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);
}
"@

# Try to send keys
[System.Windows.Forms.SendKeys]::SendWait("3")
Start-Sleep -Milliseconds 500

# Send 'j' to test navigation
[System.Windows.Forms.SendKeys]::SendWait("j")
Start-Sleep -Milliseconds 500

# Kill the process
$proc.Kill()

# Check the log
Write-Host "`nLog output:" -ForegroundColor Cyan
Get-Content "_Logs/praxis.log" | Select-Object -Last 50
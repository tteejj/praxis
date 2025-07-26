#!/usr/bin/env pwsh

# Test tab 7 initialization with debug output
Write-Host "Starting PRAXIS with debug to test Tab 7 initialization..." -ForegroundColor Cyan
Write-Host "This will:" -ForegroundColor Yellow
Write-Host "1. Start PRAXIS with debug mode" -ForegroundColor Green
Write-Host "2. Automatically switch to tab 7 (Macro Factory)" -ForegroundColor Green 
Write-Host "3. Show debug logs to see what's happening" -ForegroundColor Green
Write-Host "4. Auto-quit after 5 seconds" -ForegroundColor Green
Write-Host ""

# Start PRAXIS with debug and capture output
$process = Start-Process -FilePath "pwsh" -ArgumentList "-File", "$PSScriptRoot/Start.ps1", "-Debug" -PassThru -RedirectStandardOutput "$PSScriptRoot/debug-output.txt" -RedirectStandardError "$PSScriptRoot/debug-error.txt"

# Wait a moment for startup
Start-Sleep -Seconds 2

# Send key to switch to tab 7
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait("7")

# Wait a moment for tab switch
Start-Sleep -Seconds 2

# Send quit command
[System.Windows.Forms.SendKeys]::SendWait("q")

# Wait for process to end
$process.WaitForExit(5000)

# Show debug output
Write-Host "Debug Output:" -ForegroundColor Cyan
Get-Content "$PSScriptRoot/debug-output.txt" | Select-Object -Last 50

Write-Host "`nError Output:" -ForegroundColor Red
Get-Content "$PSScriptRoot/debug-error.txt" | Select-Object -Last 20

# Clean up
Remove-Item "$PSScriptRoot/debug-output.txt" -ErrorAction SilentlyContinue
Remove-Item "$PSScriptRoot/debug-error.txt" -ErrorAction SilentlyContinue
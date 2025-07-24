#!/usr/bin/env pwsh
# Manual test to debug tab switching

Write-Host "=== Manual Input Debug Test ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will start PRAXIS with detailed debug logging."
Write-Host "Focus on testing:"  
Write-Host "1. App starts on Projects tab (should show '1:Projects' highlighted)" -ForegroundColor Yellow
Write-Host "2. Press '2' - does the tab highlight move to '2:Tasks'?" -ForegroundColor Yellow
Write-Host "3. Press '3' - does it switch to Files?" -ForegroundColor Yellow
Write-Host "4. Press 'q' to quit cleanly" -ForegroundColor Yellow
Write-Host ""
Write-Host "Watch the terminal carefully for ANY visual changes when pressing 2 or 3." -ForegroundColor Red
Write-Host ""

# Clear the log first
Clear-Content _Logs/praxis.log -ErrorAction SilentlyContinue

# Start PRAXIS with debug logging
Write-Host "Starting PRAXIS with debug logging..." -ForegroundColor Green
pwsh -File Start.ps1 -Debug

Write-Host ""
Write-Host "=== Post-Test Log Analysis ===" -ForegroundColor Cyan

# Look for key press events
Write-Host ""
Write-Host "Key press events found:" -ForegroundColor Yellow
grep "Key pressed:\|ScreenManager.ProcessInput\|HandleInput" _Logs/praxis.log | tail -10

# Look for ShortcutManager activity
Write-Host ""
Write-Host "ShortcutManager activity:" -ForegroundColor Yellow
grep "ShortcutManager" _Logs/praxis.log | tail -5

# Look for TabContainer activity
Write-Host ""
Write-Host "TabContainer activity:" -ForegroundColor Yellow
grep "TabContainer\|ActivateTab\|tab.*switch" _Logs/praxis.log | tail -5
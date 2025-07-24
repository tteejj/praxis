#!/usr/bin/env pwsh
# Test the proper input flow to understand where tab switching breaks

Write-Host "=== Testing Proper Input Flow ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Will start PRAXIS and test number key tab switching:" -ForegroundColor Yellow
Write-Host "1. Start on Projects tab (1)" -ForegroundColor Yellow
Write-Host "2. Press '2' to test switching to Tasks" -ForegroundColor Yellow  
Write-Host "3. Press '3' to test switching to Files" -ForegroundColor Yellow
Write-Host "4. Press '4' to test switching to Editor" -ForegroundColor Yellow
Write-Host ""
Write-Host "Watch the logs to see where the input flow breaks." -ForegroundColor Green
Write-Host "Expected flow: ScreenManager -> ShortcutManager -> Screen -> TabContainer" -ForegroundColor Green
Write-Host ""

# Clear log first
> _Logs/praxis.log

# Start PRAXIS
pwsh -File Start.ps1 -Debug
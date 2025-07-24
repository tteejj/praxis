#!/usr/bin/env pwsh
# Test TextEditor mode system

Write-Host "=== Testing TextEditor Mode System ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This test will:" -ForegroundColor Yellow
Write-Host "1. Start PRAXIS" -ForegroundColor Yellow  
Write-Host "2. Switch to Editor tab (press 5)" -ForegroundColor Yellow
Write-Host "3. Type some text" -ForegroundColor Yellow
Write-Host "4. Press ESC to enter COMMAND MODE" -ForegroundColor Yellow
Write-Host "5. Press number keys to switch tabs" -ForegroundColor Yellow
Write-Host "6. Press Q to quit" -ForegroundColor Yellow
Write-Host ""
Write-Host "Look for '[COMMAND]' in the status bar after pressing ESC" -ForegroundColor Green
Write-Host ""

Read-Host "Press Enter to start PRAXIS..."

# Start PRAXIS
pwsh -File Start.ps1

# Show logs after exit
Write-Host ""
Write-Host "=== Checking Logs for Mode Changes ===" -ForegroundColor Cyan
Get-Content _Logs/praxis.log | Select-String -Pattern "InTextMode|ESC pressed|not handling number key|TabContainer.*Switching" | Select-Object -Last 20
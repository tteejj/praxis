#!/usr/bin/env pwsh
# Test screen shortcuts

Write-Host "=== Testing Screen Shortcuts ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Press 1 to go to Projects tab" -ForegroundColor Yellow
Write-Host "2. Press 'n' for New Project" -ForegroundColor Yellow
Write-Host "3. Press 'e' for Edit Project" -ForegroundColor Yellow
Write-Host "4. Check if shortcuts work" -ForegroundColor Yellow
Write-Host ""

# Clear log
"" > _Logs/praxis.log

# Start PRAXIS
pwsh -File Start.ps1

Write-Host ""
Write-Host "=== Checking logs for shortcut handling ===" -ForegroundColor Cyan
Get-Content _Logs/praxis.log | Select-String -Pattern "HandleScreenInput|HandleInput.*'n'|HandleInput.*'e'|Screen shortcuts handled" | Select-Object -Last 20
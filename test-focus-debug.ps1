#!/usr/bin/env pwsh
# Debug focus and shortcuts

Write-Host "=== Testing Focus and Shortcuts ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tests to perform:" -ForegroundColor Yellow
Write-Host "1. Press 1 - Go to Projects tab" -ForegroundColor Yellow
Write-Host "2. Press n - Should open New Project dialog" -ForegroundColor Yellow
Write-Host "3. Press 3 - Go to Files tab (was 4, now 3 without Dashboard)" -ForegroundColor Yellow
Write-Host "4. Check if Files tab shows blue border when focused" -ForegroundColor Yellow
Write-Host "5. Use arrow keys in Files tab" -ForegroundColor Yellow
Write-Host ""

# Clear log
"" > _Logs/praxis.log

# Start PRAXIS
pwsh -File Start.ps1

Write-Host ""
Write-Host "=== Focus Debug Info ===" -ForegroundColor Cyan
Get-Content _Logs/praxis.log | Select-String -Pattern "Focus|HandleScreenInput|Screen shortcuts|FileBrowser.*activated|FastFileTree.*focus" | Select-Object -Last 30
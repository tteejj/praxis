#!/usr/bin/env pwsh
# Test shortcut flow

Write-Host "=== Testing Shortcut Flow ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will help debug why shortcuts aren't working" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Start PRAXIS" -ForegroundColor Yellow
Write-Host "2. Press 1 to go to Projects tab" -ForegroundColor Yellow
Write-Host "3. Press 'n' to test New Project shortcut" -ForegroundColor Yellow
Write-Host "4. Watch the logs below for debug output" -ForegroundColor Yellow
Write-Host "5. Press Q to quit" -ForegroundColor Yellow
Write-Host ""

# Clear log
"" > _Logs/praxis.log

Read-Host "Press Enter to start PRAXIS..."

# Start PRAXIS
pwsh -File Start.ps1

Write-Host ""
Write-Host "=== Checking Shortcut Debug Info ===" -ForegroundColor Cyan
Get-Content _Logs/praxis.log | Select-String -Pattern "ShortcutManager|HandleKeyPress|RegisterShortcut|Total shortcuts|Screen=Projects|ScreenType=" | Select-Object -Last 30 | ForEach-Object {
    $line = $_.ToString()
    if ($line -match "ShortcutManager.HandleKeyPress") {
        Write-Host $line -ForegroundColor Yellow
    } elseif ($line -match "Total shortcuts") {
        Write-Host $line -ForegroundColor Cyan
    } elseif ($line -match "Screen=") {
        Write-Host $line -ForegroundColor Green
    } else {
        Write-Host $line
    }
}
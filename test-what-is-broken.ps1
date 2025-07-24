#!/usr/bin/env pwsh
# Test what exactly is broken with tab switching

Write-Host "=== Testing What Is Actually Broken ===" -ForegroundColor Red
Write-Host ""
Write-Host "This will test the exact scenario:"
Write-Host "1. Start PRAXIS (should be on Projects tab)"
Write-Host "2. Press '2' to switch to Tasks"  
Write-Host "3. Observe if ANYTHING changes visually"
Write-Host ""
Write-Host "If tab switching was working before but is broken now:"
Write-Host "- The tab bar highlight should move"
Write-Host "- The screen content should change from Projects to Tasks"
Write-Host ""
Write-Host "Let's see what happens..." -ForegroundColor Yellow

# Clear log to get clean output
Clear-Content _Logs/praxis.log -ErrorAction SilentlyContinue

# Start PRAXIS
Write-Host "Starting PRAXIS..." -ForegroundColor Green
timeout 30s pwsh -File Start.ps1 -Debug || pwsh -File Start.ps1 -Debug

Write-Host ""  
Write-Host "=== Log Analysis ===" -ForegroundColor Cyan

# Check if any keys were pressed
Write-Host "Keys pressed:" -ForegroundColor Yellow
grep "Key pressed:" _Logs/praxis.log | tail -5

# Check if TabContainer handled any switching
Write-Host ""
Write-Host "Tab switching attempts:" -ForegroundColor Yellow  
grep -i "tab.*switch\|activate.*tab" _Logs/praxis.log | tail -5

# Check ShortcutManager activity
Write-Host ""
Write-Host "ShortcutManager activity:" -ForegroundColor Yellow
grep "ShortcutManager" _Logs/praxis.log | tail -5
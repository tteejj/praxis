#!/usr/bin/env pwsh
# Test TextEditor ESC behavior

Write-Host "=== Testing TextEditor ESC Behavior ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Press 5 to go to Editor tab" -ForegroundColor Yellow
Write-Host "2. Type some text" -ForegroundColor Yellow
Write-Host "3. Press ESC" -ForegroundColor Yellow
Write-Host "4. Try pressing 1, 2, 3 to switch tabs" -ForegroundColor Yellow
Write-Host "5. Press Q to quit" -ForegroundColor Yellow
Write-Host ""

Clear-Content _Logs/praxis.log -ErrorAction SilentlyContinue

pwsh -File Start.ps1

Write-Host ""
Write-Host "=== Checking Key Input After ESC ===" -ForegroundColor Cyan
grep -a "Key pressed\|InTextMode\|HandleInput.*TextEditor" _Logs/praxis.log | tail -30
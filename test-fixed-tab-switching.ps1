#!/usr/bin/env pwsh
# Test the fixed tab switching from any screen

Write-Host "=== Testing Fixed Tab Switching ===" -ForegroundColor Cyan
Write-Host "This test will verify that number keys work for tab switching from any screen." -ForegroundColor Yellow
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. App will start on Projects tab (tab 1)"
Write-Host "2. Press '2' to switch to Tasks tab"
Write-Host "3. Press '3' to switch to Files tab"  
Write-Host "4. Press '4' to switch to Editor tab"
Write-Host "5. Press ESC to enter command mode in editor"
Write-Host "6. Press '1' to switch back to Projects tab"
Write-Host "7. Press Q to quit"
Write-Host ""
Write-Host "If the fix works, you should be able to switch tabs from ANY screen using 1-5 keys." -ForegroundColor Green
Write-Host ""
Write-Host "Starting PRAXIS..." -ForegroundColor Green

# Start PRAXIS
pwsh -File Start.ps1
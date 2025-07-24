#!/usr/bin/env pwsh
# Test current actual behavior across different screens

# Change to PRAXIS directory
Set-Location $PSScriptRoot

Write-Host "=== Testing Current Tab Switching Behavior ===" -ForegroundColor Cyan
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. App will start"
Write-Host "2. Press '4' to go to Editor tab"
Write-Host "3. Press ESC to enter command mode"
Write-Host "4. Press '1' to switch to Projects tab"
Write-Host "5. Press '2' to switch to Tasks tab"
Write-Host "6. Press Q to quit"
Write-Host ""
Write-Host "If tab switching works, you should see tab changes."
Write-Host "If it doesn't work, tabs won't switch when pressing 1-6."
Write-Host ""
Write-Host "Starting PRAXIS in 3 seconds..." -ForegroundColor Green
Start-Sleep 3

# Start PRAXIS
pwsh -File Start.ps1
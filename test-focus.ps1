#!/usr/bin/env pwsh
# Simple test to verify focus navigation in TaskScreen

Write-Host "Testing PRAXIS TaskScreen focus navigation..." -ForegroundColor Yellow
Write-Host "Instructions:" -ForegroundColor Cyan
Write-Host "  1. Press '2' to switch to Tasks tab" -ForegroundColor White
Write-Host "  2. Press Tab to switch between filter box and task list" -ForegroundColor White
Write-Host "  3. Watch for border color changes (blue = focused)" -ForegroundColor White
Write-Host "  4. Press 'q' or Escape to quit" -ForegroundColor White
Write-Host ""
Write-Host "Starting in 3 seconds..." -ForegroundColor Green
Start-Sleep -Seconds 3

# Run the main app
& "$PSScriptRoot/Start.ps1"
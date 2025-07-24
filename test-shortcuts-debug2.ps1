#!/usr/bin/env pwsh
# Simple test to check if shortcuts are working

# Clear any existing log
if (Test-Path "_Logs/praxis.log") {
    Clear-Content "_Logs/praxis.log"
}

Write-Host "`nStarting PRAXIS with shortcut debugging..." -ForegroundColor Cyan
Write-Host "Watch for debug messages about shortcuts" -ForegroundColor Yellow
Write-Host "Press 'e' or 'd' on screens 1 or 2" -ForegroundColor Yellow
Write-Host "`nStarting in 2 seconds..." -ForegroundColor Gray
Start-Sleep -Seconds 2

# Run PRAXIS with debug mode
pwsh -File Start.ps1 -Debug
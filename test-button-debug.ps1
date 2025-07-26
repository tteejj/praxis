#!/usr/bin/env pwsh

# Test CommandEditDialog button with detailed debugging
Write-Host "Starting PRAXIS for button debugging..." -ForegroundColor Cyan
Write-Host "Navigate to Commands tab, press 'n' to create new command" -ForegroundColor Green
Write-Host "Try clicking the OK button to see detailed error logs" -ForegroundColor Green
Write-Host "Press Ctrl+Q to exit when done" -ForegroundColor Yellow

# Clear log file to see only current session
if (Test-Path "$PSScriptRoot/_Logs/praxis.log") {
    Clear-Content "$PSScriptRoot/_Logs/praxis.log"
}

# Run the application
& "$PSScriptRoot/Start.ps1"

# Show logs after exit
Write-Host "`n=== LOGS ===" -ForegroundColor Cyan
Get-Content "$PSScriptRoot/_Logs/praxis.log" | Select-Object -Last 20
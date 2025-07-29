#!/usr/bin/env pwsh

# Test script to isolate the "2" key freeze issue

Write-Host "Testing '2' key freeze..." -ForegroundColor Cyan

# Start the app in the background and send "2" key after a short delay
$job = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    
    # Start the app
    pwsh -File Start.ps1
}

# Wait for app to start
Start-Sleep 3

# Now check what's in the job output
$output = Receive-Job $job -Keep
Write-Host "Job output so far:" -ForegroundColor Yellow
$output | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

# Send interrupt to stop the job
Stop-Job $job
Remove-Job $job

# Check the logs for debug output
Write-Host "`nChecking logs..." -ForegroundColor Cyan
if (Test-Path "_Logs/praxis.log") {
    Write-Host "Latest log entries:" -ForegroundColor Yellow
    Get-Content "_Logs/praxis.log" | Select-Object -Last 20 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }
} else {
    Write-Host "No log file found" -ForegroundColor Red
}

Write-Host "`nTest completed." -ForegroundColor Green
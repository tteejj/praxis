#!/usr/bin/env pwsh
# Debug file browser focus issue

# Ensure we have a log file
if (-not (Test-Path "_Logs")) {
    New-Item -ItemType Directory -Path "_Logs" -Force | Out-Null
}

# Start fresh log
"" | Out-File "_Logs/praxis.log" -Force

Write-Host "Starting PRAXIS with debug logging..." -ForegroundColor Cyan
Write-Host "Press '3' to go to file browser, then try 'j' and 'k' to navigate" -ForegroundColor Yellow

# Run in foreground so we can see what happens
try {
    & ./Start.ps1 -Debug
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`nChecking log file..." -ForegroundColor Cyan
if (Test-Path "_Logs/praxis.log") {
    $logSize = (Get-Item "_Logs/praxis.log").Length
    Write-Host "Log file size: $logSize bytes" -ForegroundColor Yellow
    
    if ($logSize -gt 0) {
        Write-Host "`nLast 20 lines of log:" -ForegroundColor Cyan
        Get-Content "_Logs/praxis.log" -Tail 20
    }
}
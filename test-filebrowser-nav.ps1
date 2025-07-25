#!/usr/bin/env pwsh
# Test file browser navigation

$ErrorActionPreference = "Stop"

# Clear log first
Clear-Content "_Logs/praxis.log"

Write-Host "Starting PRAXIS and navigating to file browser..." -ForegroundColor Cyan

# Start the application in background
$job = Start-Job -ScriptBlock {
    Set-Location $using:PSScriptRoot
    & ./Start.ps1
}

# Wait for it to start
Start-Sleep -Seconds 3

# Check the log for initialization
Write-Host "`nChecking log for FileBrowser initialization..." -ForegroundColor Yellow
$log = Get-Content "_Logs/praxis.log" | Select-String -Pattern "FileBrowser|RangerFileTree"
$log | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

# Stop the job
Stop-Job $job
Remove-Job $job

Write-Host "`nDone!" -ForegroundColor Green
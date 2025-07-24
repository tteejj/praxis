#!/usr/bin/env pwsh
# Quick test to see startup behavior

Write-Host "Starting PRAXIS to check startup..." -ForegroundColor Yellow
Write-Host "If you see a black screen, press Ctrl+C to exit" -ForegroundColor Red
Write-Host ""

# Clear log
Clear-Content _Logs/praxis.log -ErrorAction SilentlyContinue

# Start app
try {
    pwsh -File Start.ps1
} catch {
    Write-Host "Error during startup: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Checking startup logs..." -ForegroundColor Cyan

# Check tab initialization
Write-Host ""
Write-Host "Tab initialization:" -ForegroundColor Yellow
grep -E "Adding tabs|Added.*tabs|ActivateTab|ActiveTabIndex" _Logs/praxis.log | head -10

# Check for errors
Write-Host ""
Write-Host "Errors:" -ForegroundColor Yellow
grep -E "ERROR|Exception" _Logs/praxis.log | head -10
# Quick test script to validate the time entry fix
# This will launch Praxis and check if time entries refresh properly

Write-Host "Testing time entry refresh fix..." -ForegroundColor Green

# Set global variables
$global:PraxisRoot = $PSScriptRoot

# Load and test
try {
    . "$PSScriptRoot/Start.ps1"
    Write-Host "Application started successfully" -ForegroundColor Green
} catch {
    Write-Host "Error starting application: $_" -ForegroundColor Red
    exit 1
}
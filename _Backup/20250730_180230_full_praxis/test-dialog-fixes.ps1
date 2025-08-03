#!/usr/bin/env pwsh
# Test dialog fixes

# Start the application and go directly to Projects screen
Write-Host "Starting PRAXIS with dialog fixes..." -ForegroundColor Green
Write-Host "This will open the Projects screen" -ForegroundColor Yellow
Write-Host "Press 'n' to test the New Project dialog" -ForegroundColor Yellow
Write-Host "Check that:" -ForegroundColor Cyan
Write-Host "  1. Dialog appears centered on screen" -ForegroundColor Cyan
Write-Host "  2. Background is dark blue/black, NOT gray" -ForegroundColor Cyan
Write-Host "  3. Border is visible with blue color" -ForegroundColor Cyan
Write-Host "  4. All fields are properly positioned" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Run the application
& "$PSScriptRoot/Start.ps1"
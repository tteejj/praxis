#!/usr/bin/env pwsh
# Test script for dialogs

Write-Host "Testing PRAXIS Task Dialogs..." -ForegroundColor Yellow
Write-Host "Instructions:" -ForegroundColor Cyan
Write-Host "  1. Press '2' to switch to Tasks tab" -ForegroundColor White
Write-Host "  2. Press 'n' to create a new task" -ForegroundColor White
Write-Host "  3. Press 'e' or Enter to edit a task" -ForegroundColor White
Write-Host "  4. Press 'd' or Delete to delete a task" -ForegroundColor White
Write-Host "  5. Use Tab to navigate within dialogs" -ForegroundColor White
Write-Host "  6. Press 'q' or Escape to quit" -ForegroundColor White
Write-Host ""
Write-Host "Starting in 3 seconds..." -ForegroundColor Green
Start-Sleep -Seconds 3

# Run the main app
& "$PSScriptRoot/Start.ps1"
#!/usr/bin/env pwsh

Write-Host "Testing PRAXIS with double buffer..." -ForegroundColor Cyan
Write-Host "The double buffer implementation:" -ForegroundColor Yellow
Write-Host "- Stores the last rendered content as a string"
Write-Host "- Only writes to console if content has changed"
Write-Host "- Should reduce flicker and improve performance"
Write-Host ""
Write-Host "Starting PRAXIS..." -ForegroundColor Green
Write-Host "Press Ctrl+C to exit"
Write-Host ""

# Run the application
& ./Start.ps1
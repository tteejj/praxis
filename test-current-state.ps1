#!/usr/bin/env pwsh
# Test current state - does tab switching work at all?

Write-Host "=== Current State Test ===" -ForegroundColor Red
Write-Host ""
Write-Host "Testing if number key tab switching works AT ALL."
Write-Host ""
Write-Host "Expected behavior:" -ForegroundColor Yellow
Write-Host "- Start on Projects tab (should show 1:Projects highlighted)"
Write-Host "- Press '2' → should switch to Tasks tab"
Write-Host "- Press '3' → should switch to Files tab"
Write-Host "- Press '4' → should switch to Editor tab"
Write-Host ""
Write-Host "If NOTHING happens when pressing 2/3/4, then tab switching is completely broken."
Write-Host ""
Write-Host "Starting PRAXIS now..." -ForegroundColor Green

pwsh -File Start.ps1
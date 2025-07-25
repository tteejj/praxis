#!/usr/bin/env pwsh

# Quick test to see if TimeEntryScreen loads

. ./Start.ps1 -Test 2>$null

try {
    $screen = [TimeEntryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    Write-Host "TimeEntryScreen loaded successfully!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
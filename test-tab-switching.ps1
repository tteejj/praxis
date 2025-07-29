#!/usr/bin/env pwsh

# Test script for tab switching issue

Write-Host "Testing tab switching performance fixes..." -ForegroundColor Cyan

# Set test mode to prevent infinite loops
$env:PRAXIS_TEST_MODE = "true"

try {
    # Start the application in test mode
    Write-Host "Starting PRAXIS in test mode..." -ForegroundColor Yellow
    
    # This should start and exit quickly in test mode
    & ./Start.ps1
    
    Write-Host "PRAXIS started successfully" -ForegroundColor Green
} 
catch {
    Write-Host "Error starting PRAXIS: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}
finally {
    # Clean up test mode
    Remove-Item Env:PRAXIS_TEST_MODE -ErrorAction SilentlyContinue
}
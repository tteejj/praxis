#!/usr/bin/env pwsh

# Test CommandLibraryScreen in live application environment
Write-Host "Testing CommandLibraryScreen in live application..." -ForegroundColor Cyan

# Start the application normally
Write-Host "Starting PRAXIS application..." -ForegroundColor Yellow
Write-Host "- Navigate to Commands tab and test keyboard shortcuts" -ForegroundColor Green
Write-Host "- Press 'n' to create new command" -ForegroundColor Green  
Write-Host "- Press 'e' to edit selected command" -ForegroundColor Green
Write-Host "- Press 'd' to delete selected command" -ForegroundColor Green
Write-Host "- Press Enter to copy command to clipboard" -ForegroundColor Green
Write-Host "- Use arrow keys to navigate commands" -ForegroundColor Green
Write-Host "- Type to search commands (excludes n/e/d)" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "Press Ctrl+Q to exit when done testing" -ForegroundColor Yellow

# Run the actual application
& "$PSScriptRoot/Start.ps1"
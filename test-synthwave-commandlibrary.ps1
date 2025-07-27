#!/usr/bin/env pwsh
# Test script to launch PRAXIS with synthwave theme and navigate to Command Library

Write-Host "Launching PRAXIS with synthwave-84 theme..." -ForegroundColor Magenta
Write-Host "Press '7' to navigate to Command Library screen" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Yellow

# Launch with synthwave theme
./Start.ps1 -Theme "synthwave-84"
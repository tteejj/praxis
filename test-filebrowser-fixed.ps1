#!/usr/bin/env pwsh
# Test file browser with fixed focus

$ErrorActionPreference = "Stop"

# Clear log
"" | Out-File "_Logs/praxis.log"

Write-Host "Testing file browser navigation..." -ForegroundColor Cyan
Write-Host "1. Start app and go to file browser (key 3)" -ForegroundColor Yellow
Write-Host "2. Test vim navigation (h/j/k/l)" -ForegroundColor Yellow
Write-Host ""

# Just run the app
& ./Start.ps1
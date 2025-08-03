#!/usr/bin/env pwsh
# Find the source of grey rendering

. "$PSScriptRoot/Start.ps1"

Write-Host "`nStarting PRAXIS to test grey issue..." -ForegroundColor Yellow
Write-Host "Watch for grey backgrounds in the New Project dialog" -ForegroundColor Cyan
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# The app is now running - user needs to open New Project dialog manually
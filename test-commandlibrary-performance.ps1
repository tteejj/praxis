#!/usr/bin/env pwsh
# Test CommandLibrary performance improvements

Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "Testing CommandLibrary performance improvements..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Changes made:" -ForegroundColor Yellow
Write-Host "✓ Added StringCache loading for performance" -ForegroundColor Green
Write-Host "✓ Replaced full screen Clear() with targeted ClearLine()" -ForegroundColor Green  
Write-Host "✓ Implemented render caching - only update when changed" -ForegroundColor Green
Write-Host "✓ Removed direct Write-Host calls from dialogs" -ForegroundColor Green
Write-Host "✓ Optimized SimpleListBox clearing" -ForegroundColor Green
Write-Host ""
Write-Host "The app should now be flicker-free like SimpleTaskPro!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to launch CommandLibrary..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Launch CommandLibrary
& "$PSScriptRoot/CommandLibrary/CommandLibrary.ps1"
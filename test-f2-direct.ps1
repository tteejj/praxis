#!/usr/bin/env pwsh
# test-f2-direct.ps1 - Test F2 directly without redirection

Write-Host "Starting SimpleTaskPro directly (no redirection)..." -ForegroundColor Cyan
Write-Host "Press F2 to test CommandLibrary switching" -ForegroundColor Yellow
Write-Host "Press Q to quit if it works" -ForegroundColor Green
Write-Host ""

try {
    . './TaskPro/SimpleTaskPro.ps1'
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}
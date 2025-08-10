#!/usr/bin/env pwsh

Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "OS: $($PSVersionTable.OS)"
Write-Host "Platform: $($PSVersionTable.Platform)"

Write-Host "`nTesting Console methods..."

try {
    Write-Host "KeyAvailable: $([Console]::KeyAvailable)" -ForegroundColor Green
} catch {
    Write-Host "KeyAvailable failed: $_" -ForegroundColor Red
}

try {
    Write-Host "CursorLeft: $([Console]::CursorLeft)" -ForegroundColor Green
} catch {
    Write-Host "CursorLeft failed: $_" -ForegroundColor Red
}

try {
    Write-Host "WindowWidth: $([Console]::WindowWidth)" -ForegroundColor Green
} catch {
    Write-Host "WindowWidth failed: $_" -ForegroundColor Red
}
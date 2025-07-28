#!/usr/bin/env pwsh

# Direct theme cycling test
Set-Location $PSScriptRoot

Write-Host "Starting PRAXIS to test theme cycling..." -ForegroundColor Green
Write-Host "Press 't' in Settings or Ctrl+T anywhere to cycle themes" -ForegroundColor Yellow
Write-Host "Current settings.json theme: " -NoNewline
$settings = Get-Content "_Config/settings.json" | ConvertFrom-Json
Write-Host $settings.Theme.CurrentTheme -ForegroundColor Cyan

# Start the app
& pwsh -File Start.ps1
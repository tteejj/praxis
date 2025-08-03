#!/usr/bin/env pwsh

# Quick test of migrated ProjectsScreen
Write-Host "Loading framework..." -ForegroundColor Green
try {
    . "$PSScriptRoot/Start.ps1" -LoadOnly
    Write-Host "✓ Framework loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Framework failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Creating ProjectsScreen..." -ForegroundColor Green
try {
    $projectsScreen = [ProjectsScreen]::new()
    Write-Host "✓ ProjectsScreen created" -ForegroundColor Green
} catch {
    Write-Host "✗ ProjectsScreen creation failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}

Write-Host "Testing ProjectsScreen..." -ForegroundColor Green
try {
    $global:ScreenManager.Push($projectsScreen)
    Write-Host "Press Ctrl+Q to quit, n for new project, e to edit, d to delete" -ForegroundColor Yellow
    $global:ScreenManager.Run()
} catch {
    Write-Host "✗ ProjectsScreen runtime error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}
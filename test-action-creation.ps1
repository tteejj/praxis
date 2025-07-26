#!/usr/bin/env pwsh

# Test action creation to see what's failing
. "$PSScriptRoot/Start.ps1" -LoadOnly

Write-Host "Testing Action class creation..." -ForegroundColor Green

try {
    Write-Host "Testing BaseAction..." -ForegroundColor Yellow
    $baseAction = [BaseAction]::new()
    Write-Host "✓ BaseAction created successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ BaseAction failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "Testing SummarizationAction..." -ForegroundColor Yellow
    $summarizationAction = [SummarizationAction]::new()
    Write-Host "✓ SummarizationAction created successfully: $($summarizationAction.Name)" -ForegroundColor Green
} catch {
    Write-Host "✗ SummarizationAction failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "Testing AppendFieldAction..." -ForegroundColor Yellow
    $appendFieldAction = [AppendFieldAction]::new()
    Write-Host "✓ AppendFieldAction created successfully: $($appendFieldAction.Name)" -ForegroundColor Green
} catch {
    Write-Host "✗ AppendFieldAction failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "Testing ExportToExcelAction..." -ForegroundColor Yellow
    $exportAction = [ExportToExcelAction]::new()
    Write-Host "✓ ExportToExcelAction created successfully: $($exportAction.Name)" -ForegroundColor Green
} catch {
    Write-Host "✗ ExportToExcelAction failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Write-Host "Testing CustomIdeaCommandAction..." -ForegroundColor Yellow
    $customAction = [CustomIdeaCommandAction]::new()
    Write-Host "✓ CustomIdeaCommandAction created successfully: $($customAction.Name)" -ForegroundColor Green
} catch {
    Write-Host "✗ CustomIdeaCommandAction failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nAction creation test completed!" -ForegroundColor Cyan
#!/usr/bin/env pwsh

# Simple action creation test without starting PRAXIS
param([switch]$LoadOnly)

# Load framework components without starting UI
. "$PSScriptRoot/Core/StringCache.ps1"
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Core/ServiceContainer.ps1"
. "$PSScriptRoot/Core/StringBuilderPool.ps1"

# Services
. "$PSScriptRoot/Services/Logger.ps1"
. "$PSScriptRoot/Services/EventBus.ps1"
. "$PSScriptRoot/Services/ThemeManager.ps1"

# Base classes
. "$PSScriptRoot/Base/UIElement.ps1"
. "$PSScriptRoot/Base/Container.ps1"
. "$PSScriptRoot/Base/Screen.ps1"
. "$PSScriptRoot/Base/BaseModel.ps1"

# Models
. "$PSScriptRoot/Models/BaseAction.ps1"

# Actions
. "$PSScriptRoot/Actions/CustomIdeaCommandAction.ps1"
. "$PSScriptRoot/Actions/SummarizationAction.ps1"
. "$PSScriptRoot/Actions/AppendFieldAction.ps1"
. "$PSScriptRoot/Actions/ExportToExcelAction.ps1"

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
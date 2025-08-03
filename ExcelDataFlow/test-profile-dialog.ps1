#!/usr/bin/env pwsh

Write-Host "Testing ProfileSelectionDialog constructor..." -ForegroundColor Green

try {
    # Load dependencies
    . "$PSScriptRoot/Core/VT100.ps1"
    . "$PSScriptRoot/Base/SimpleDialog.ps1"
    . "$PSScriptRoot/Services/ConfigurationService.ps1"
    . "$PSScriptRoot/Services/ExportProfileService.ps1"
    . "$PSScriptRoot/Services/TextExportService.ps1"
    . "$PSScriptRoot/Screens/ProfileSelectionDialog.ps1"
    
    Write-Host "✅ All classes loaded successfully" -ForegroundColor Green
    
    # Test creating ProfileSelectionDialog
    $dialog = [ProfileSelectionDialog]::new()
    Write-Host "✅ ProfileSelectionDialog created successfully" -ForegroundColor Green
    
    Write-Host "Constructor fix successful!" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}
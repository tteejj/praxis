#!/usr/bin/env pwsh

Write-Host "Testing ExcelDataFlow startup..." -ForegroundColor Green
Write-Host "If you see a dialog, the app is working correctly!" -ForegroundColor Yellow

try {
    # Test if the classes load without error
    . "$PSScriptRoot/Core/VT100.ps1"
    . "$PSScriptRoot/Base/SimpleDialog.ps1"
    . "$PSScriptRoot/Screens/StartupSelectionDialog.ps1"
    
    Write-Host "✅ All core classes loaded successfully" -ForegroundColor Green
    
    # Create dialog instance
    $dialog = [StartupSelectionDialog]::new()
    Write-Host "✅ StartupSelectionDialog created successfully" -ForegroundColor Green
    
    # Test render
    $output = $dialog.Render()
    Write-Host "✅ Dialog renders without errors" -ForegroundColor Green
    
    Write-Host "`nApp is ready to run! No UnifiedDialog errors detected." -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Error detected: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}
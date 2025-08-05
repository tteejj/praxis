#!/usr/bin/env pwsh

Write-Host "Testing ProfileSelectionDialog with debug info..." -ForegroundColor Green

try {
    # Load dependencies
    . "$PSScriptRoot/Core/VT100.ps1"
    . "$PSScriptRoot/Base/SimpleDialog.ps1"
    . "$PSScriptRoot/Services/ConfigurationService.ps1"
    . "$PSScriptRoot/Services/ExportProfileService.ps1"
    . "$PSScriptRoot/Services/TextExportService.ps1"
    . "$PSScriptRoot/Screens/ProfileSelectionDialog.ps1"
    
    Write-Host "✅ Classes loaded" -ForegroundColor Green
    
    # Create dialog and check initial state
    $dialog = [ProfileSelectionDialog]::new()
    
    Write-Host "✅ Dialog created" -ForegroundColor Green
    Write-Host "Initial Selected Profile: '$($dialog.SelectedProfile)'" -ForegroundColor Cyan
    Write-Host "Profile Names Count: $($dialog._profileNames.Count)" -ForegroundColor Cyan
    Write-Host "Options Count: $($dialog.Options.Count)" -ForegroundColor Cyan
    Write-Host "Selected Index: $($dialog.SelectedIndex)" -ForegroundColor Cyan
    
    if ($dialog._profileNames.Count -eq 0) {
        Write-Host "⚠️  No profiles found - this would cause issues" -ForegroundColor Yellow
    } else {
        Write-Host "✅ Profiles available:" -ForegroundColor Green
        for ($i = 0; $i -lt $dialog._profileNames.Count; $i++) {
            Write-Host "  [$i] $($dialog._profileNames[$i])" -ForegroundColor Gray
        }
    }
    
    # Test the export method directly
    Write-Host "`nTesting ExportWithSelectedProfile method..." -ForegroundColor Yellow
    $dialog.ExportWithSelectedProfile()
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}
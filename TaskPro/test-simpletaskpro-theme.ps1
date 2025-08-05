#!/usr/bin/env pwsh
# Test SimpleTaskPro theme integration

Set-Location $PSScriptRoot

try {
    Write-Host "Testing SimpleTaskPro theme integration..." -ForegroundColor Cyan
    
    # Load components
    . "$PSScriptRoot/Core/StringCache.ps1"
    . "$PSScriptRoot/Core/VT100.ps1"
    . "$PSScriptRoot/Services/UnifiedThemeService.ps1"
    . "$PSScriptRoot/Screens/ColorPickerDialog.ps1"
    . "$PSScriptRoot/Screens/HybridColorPickerDialog.ps1"
    . "$PSScriptRoot/Screens/EnhancedThemeSettingsScreen.ps1"
    
    # Initialize themes
    $userDataPath = Join-Path $PSScriptRoot "Data"
    if (-not (Test-Path $userDataPath)) {
        New-Item -ItemType Directory -Path $userDataPath -Force | Out-Null
    }
    [UnifiedThemeService]::Initialize($userDataPath)
    
    Write-Host "`n✓ Theme system loaded successfully!" -ForegroundColor Green
    
    # Test theme API
    Write-Host "`nTesting Theme API..." -ForegroundColor Cyan
    Write-Host "Current theme: $([Theme]::Current())" -ForegroundColor Yellow
    Write-Host "Available themes: $([Theme]::List() -join ', ')" -ForegroundColor Yellow
    
    # Test color output
    Write-Host "`nTesting theme colors:" -ForegroundColor Cyan
    Write-Host ([Theme]::Style("Primary text color", "text.primary"))
    Write-Host ([Theme]::Style("Accent text color", "text.accent"))
    Write-Host ([Theme]::Style("Success status", "status.success"))
    Write-Host ([Theme]::Style("Error status", "status.error"))
    Write-Host ([Theme]::Style("Warning status", "status.warning"))
    Write-Host ([Theme]::Style("Info status", "status.info"))
    
    # Test ColorThemeService compatibility
    Write-Host "`nTesting ColorThemeService compatibility:" -ForegroundColor Cyan
    . "$PSScriptRoot/Services/ColorThemeService.ps1"
    
    $taskColor = [ColorThemeService]::GetTaskColor("work")
    Write-Host "${taskColor}Work task color${VT.Reset}"
    
    $subtaskColor = [ColorThemeService]::GetSubtaskColor("work")
    Write-Host "${subtaskColor}Subtask color${VT.Reset}"
    
    Write-Host "`n✓ All theme tests passed!" -ForegroundColor Green
    
} catch {
    Write-Host "`n✗ Test failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
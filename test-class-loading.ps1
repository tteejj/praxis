#!/usr/bin/env pwsh
# Test individual class loading

Write-Host "Testing class loading..." -ForegroundColor Cyan

# Load VT100 first
try {
    . "./TaskPro/Core/StringCache.ps1"
    . "./TaskPro/Components/Shared/VT100.ps1"
    Write-Host "✓ VT100 loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ VT100 failed: $_" -ForegroundColor Red
    exit 1
}

# Test SimpleTimeEntry loading
Write-Host "Loading SimpleTimeEntry..." -ForegroundColor Yellow
try {
    . "./TaskPro/Models/External/SimpleTimeEntry.ps1"
    Write-Host "✓ SimpleTimeEntry file loaded" -ForegroundColor Green
    
    # Test if class is available
    $testEntry = [SimpleTimeEntry]::new()
    Write-Host "✓ SimpleTimeEntry class instantiable" -ForegroundColor Green
    Write-Host "  Test entry ID: $($testEntry.Id)" -ForegroundColor DarkGray
} catch {
    Write-Host "✗ SimpleTimeEntry failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Test TimeTrackingService loading
Write-Host "Loading TimeTrackingService..." -ForegroundColor Yellow
try {
    . "./TaskPro/Services/External/TimeTrackingService.ps1"
    Write-Host "✓ TimeTrackingService file loaded" -ForegroundColor Green
    
    # Test if class is available
    $testService = [TimeTrackingService]::new()
    Write-Host "✓ TimeTrackingService class instantiable" -ForegroundColor Green
    Write-Host "  Service data path: $($testService.DataPath)" -ForegroundColor DarkGray
} catch {
    Write-Host "✗ TimeTrackingService failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Test TimeListScreen loading
Write-Host "Loading TimeListScreen..." -ForegroundColor Yellow
try {
    . "./TaskPro/Screens/External/TimeListScreen.ps1"
    Write-Host "✓ TimeListScreen file loaded" -ForegroundColor Green
    
    # Test if class is available
    $testScreen = [TimeListScreen]::new()
    Write-Host "✓ TimeListScreen class instantiable" -ForegroundColor Green
    Write-Host "  Screen size: $($testScreen.Width)x$($testScreen.Height)" -ForegroundColor DarkGray
} catch {
    Write-Host "✗ TimeListScreen failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

Write-Host ""
Write-Host "✓ All TimeTracker classes loaded successfully!" -ForegroundColor Green
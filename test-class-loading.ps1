#!/usr/bin/env pwsh

# Test if dialog classes are properly loaded
Write-Host "Testing class loading..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

Write-Host "`nChecking if classes exist..." -ForegroundColor Yellow

# Test BaseDialog
try {
    $test = [BaseDialog] -as [type]
    if ($test) {
        Write-Host "  ✓ BaseDialog class found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ BaseDialog class not found" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ BaseDialog error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test CommandEditDialog
try {
    $test = [CommandEditDialog] -as [type]
    if ($test) {
        Write-Host "  ✓ CommandEditDialog class found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ CommandEditDialog class not found" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ CommandEditDialog error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test ConfirmationDialog
try {
    $test = [ConfirmationDialog] -as [type]
    if ($test) {
        Write-Host "  ✓ ConfirmationDialog class found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ ConfirmationDialog class not found" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ ConfirmationDialog error: $($_.Exception.Message)" -ForegroundColor Red
}

# Try creating instances
Write-Host "`nTesting instance creation..." -ForegroundColor Yellow

if ([CommandEditDialog] -as [type]) {
    try {
        $dialog = [CommandEditDialog]::new()
        Write-Host "  ✓ CommandEditDialog created successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ CommandEditDialog creation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  ✗ Cannot test CommandEditDialog creation - class not found" -ForegroundColor Red
}

Write-Host "`nTest completed!" -ForegroundColor Green
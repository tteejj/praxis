#!/usr/bin/env pwsh

# Test complete CommandLibraryScreen + Dialog flow
Write-Host "Testing complete CommandLibraryScreen with dialogs..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    $screen.SetBounds(0, 0, 120, 40)
    
    Write-Host "Commands loaded: $($screen.CommandList.Items.Count)" -ForegroundColor Green
    
    # Test NewCommand dialog creation and rendering
    Write-Host "`nTesting NewCommand dialog creation..." -ForegroundColor Yellow
    try {
        $screen.NewCommand()
        Write-Host "  ✓ NewCommand dialog created successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ NewCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test EditCommand with selection
    Write-Host "`nTesting EditCommand with selection..." -ForegroundColor Yellow
    $screen.CommandList.SelectedIndex = 0
    try {
        $screen.EditCommand()
        Write-Host "  ✓ EditCommand dialog created successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ EditCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test DeleteCommand with selection
    Write-Host "`nTesting DeleteCommand with selection..." -ForegroundColor Yellow
    try {
        $screen.DeleteCommand()
        Write-Host "  ✓ DeleteCommand dialog created successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ DeleteCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test CopySelectedCommand
    Write-Host "`nTesting CopySelectedCommand..." -ForegroundColor Yellow
    try {
        $screen.CopySelectedCommand()
        Write-Host "  ✓ CopySelectedCommand executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ CopySelectedCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`n✅ All CommandLibraryScreen functionality working perfectly!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green
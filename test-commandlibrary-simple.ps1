#!/usr/bin/env pwsh

# Simple test of CommandLibraryScreen functionality
Write-Host "Testing CommandLibraryScreen with fixed ScreenManager API..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    $screen.SetBounds(0, 0, 80, 25)
    
    Write-Host "Commands loaded: $($screen.CommandList.Items.Count)" -ForegroundColor Green
    
    # Test NewCommand directly
    Write-Host "`nTesting NewCommand..." -ForegroundColor Yellow
    try {
        $screen.NewCommand()
        Write-Host "  ✓ NewCommand executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ NewCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test EditCommand (no selection)
    Write-Host "`nTesting EditCommand (no selection)..." -ForegroundColor Yellow
    try {
        $screen.EditCommand()
        Write-Host "  ✓ EditCommand handled no selection correctly" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ EditCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test DeleteCommand (no selection)
    Write-Host "`nTesting DeleteCommand (no selection)..." -ForegroundColor Yellow
    try {
        $screen.DeleteCommand()
        Write-Host "  ✓ DeleteCommand handled no selection correctly" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ DeleteCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green
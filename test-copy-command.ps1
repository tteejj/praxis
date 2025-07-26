#!/usr/bin/env pwsh

# Test copy command functionality
Write-Host "Testing CopySelectedCommand..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    $screen.SetBounds(0, 0, 80, 25)
    
    Write-Host "Commands loaded: $($screen.CommandList.Items.Count)" -ForegroundColor Green
    
    # Select first command
    $screen.CommandList.SelectedIndex = 0
    $selectedCommand = $screen.CommandList.GetSelectedItem()
    Write-Host "Selected: $($selectedCommand.GetDisplayText())" -ForegroundColor Yellow
    
    # Test copy
    Write-Host "`nTesting CopySelectedCommand..." -ForegroundColor Yellow
    try {
        $screen.CopySelectedCommand()
        Write-Host "  ✓ Copy executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Copy failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green
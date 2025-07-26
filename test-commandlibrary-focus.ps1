#!/usr/bin/env pwsh

# Test CommandLibraryScreen focus
Write-Host "Testing CommandLibraryScreen focus..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    $screen.SetBounds(0, 0, 80, 25)
    
    Write-Host "Commands loaded: $($screen.CommandList.Items.Count)" -ForegroundColor Green
    Write-Host "CommandList has focus: $($screen.CommandList.IsFocused)" -ForegroundColor Cyan
    Write-Host "CommandList is focusable: $($screen.CommandList.IsFocusable)" -ForegroundColor Cyan
    Write-Host "Selected index: $($screen.CommandList.SelectedIndex)" -ForegroundColor Cyan
    
    # Test OnActivated
    Write-Host "`nTesting OnActivated..." -ForegroundColor Yellow
    $screen.OnActivated()
    Write-Host "After OnActivated - CommandList has focus: $($screen.CommandList.IsFocused)" -ForegroundColor Cyan
    
    # Test cursor navigation simulation
    Write-Host "`nTesting cursor navigation..." -ForegroundColor Yellow
    $downKey = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false)
    $oldIndex = $screen.CommandList.SelectedIndex
    
    $handled = $screen.CommandList.HandleInput($downKey)
    $newIndex = $screen.CommandList.SelectedIndex
    
    Write-Host "Down arrow handled: $handled" -ForegroundColor Cyan
    Write-Host "Index changed from $oldIndex to $newIndex" -ForegroundColor Cyan
    
    if ($newIndex -ne $oldIndex) {
        Write-Host "✓ Cursor navigation working!" -ForegroundColor Green
    } else {
        Write-Host "✗ Cursor navigation not working" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green
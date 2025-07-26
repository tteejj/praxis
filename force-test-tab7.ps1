#!/usr/bin/env pwsh

# Force test tab 7 by directly creating and testing the screen
Write-Host "Testing VisualMacroFactoryScreen directly..." -ForegroundColor Cyan

# Load full framework
. "$PSScriptRoot/Start.ps1" -LoadOnly 2>/dev/null

# Create and initialize the screen directly
try {
    Write-Host "Creating VisualMacroFactoryScreen..." -ForegroundColor Yellow
    $screen = [VisualMacroFactoryScreen]::new()
    
    Write-Host "Initializing screen..." -ForegroundColor Yellow  
    $screen.Initialize($global:ServiceContainer)
    
    Write-Host "Screen created successfully" -ForegroundColor Green
    Write-Host "  ComponentLibrary exists: $($null -ne $screen.ComponentLibrary)" -ForegroundColor Cyan
    Write-Host "  MacroSequence exists: $($null -ne $screen.MacroSequence)" -ForegroundColor Cyan
    Write-Host "  ContextPanel exists: $($null -ne $screen.ContextPanel)" -ForegroundColor Cyan
    Write-Host "  AvailableActions count: $($screen.AvailableActions.Count)" -ForegroundColor Cyan
    
    if ($screen.ComponentLibrary) {
        Write-Host "  ComponentLibrary Items count: $($screen.ComponentLibrary.Items.Count)" -ForegroundColor Cyan
        Write-Host "  ComponentLibrary _filteredItems count: $($screen.ComponentLibrary._filteredItems.Count)" -ForegroundColor Cyan
    }
    
    # Test bounds
    Write-Host "Setting test bounds..." -ForegroundColor Yellow
    $screen.SetBounds(0, 0, 120, 30)
    Write-Host "  Screen bounds: $($screen.X),$($screen.Y) - $($screen.Width)x$($screen.Height)" -ForegroundColor Cyan
    
    if ($screen.ComponentLibrary) {
        Write-Host "  ComponentLibrary bounds: $($screen.ComponentLibrary.X),$($screen.ComponentLibrary.Y) - $($screen.ComponentLibrary.Width)x$($screen.ComponentLibrary.Height)" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "Test completed!" -ForegroundColor Green
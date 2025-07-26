#!/usr/bin/env pwsh

# Test CommandLibraryScreen shortcuts with ScreenManager fix
Write-Host "Testing CommandLibraryScreen shortcuts with fixed ScreenManager..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    $screen.SetBounds(0, 0, 80, 25)
    
    Write-Host "Commands loaded: $($screen.CommandList.Items.Count)" -ForegroundColor Green
    
    # Test NewCommand with global ScreenManager
    Write-Host "`nTesting NewCommand with proper ScreenManager..." -ForegroundColor Yellow
    
    # Mock global ScreenManager
    $global:ScreenManager = [PSCustomObject]@{
        GetScreen = { 
            param($name)
            return $null  # Force creation of new dialog
        }
        RegisterScreen = { 
            param($name, $screen)
            Write-Host "  ✓ RegisterScreen called: $name" -ForegroundColor Green
        }
        Push = { 
            param($screen)
            Write-Host "  ✓ Push called with: $($screen.GetType().Name)" -ForegroundColor Green
        }
    }
    
    try {
        $screen.NewCommand()
        Write-Host "  ✓ NewCommand executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ NewCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test EditCommand (should warn about no selection)
    Write-Host "`nTesting EditCommand (no selection)..." -ForegroundColor Yellow
    try {
        $screen.EditCommand()
        Write-Host "  ✓ EditCommand handled no selection correctly" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ EditCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test with a selection
    Write-Host "`nTesting EditCommand with selection..." -ForegroundColor Yellow
    $screen.CommandList.SelectedIndex = 0  # Select first command
    try {
        $screen.EditCommand()
        Write-Host "  ✓ EditCommand with selection executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ EditCommand with selection failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green
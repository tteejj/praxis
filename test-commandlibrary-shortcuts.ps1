#!/usr/bin/env pwsh

# Test CommandLibraryScreen shortcuts
Write-Host "Testing CommandLibraryScreen keyboard shortcuts..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    $screen.SetBounds(0, 0, 80, 20)
    
    Write-Host "Commands loaded: $($screen.CommandList.Items.Count)" -ForegroundColor Green
    
    # Test shortcut registration
    $shortcutManager = $global:ServiceContainer.GetService('ShortcutManager')
    $shortcuts = $shortcutManager.GetShortcuts([ShortcutScope]::Screen, "CommandLibraryScreen")
    
    Write-Host "`nRegistered shortcuts for CommandLibraryScreen:" -ForegroundColor Cyan
    foreach ($shortcut in $shortcuts) {
        Write-Host "  $($shortcut.GetDisplayText()): $($shortcut.Name)" -ForegroundColor Yellow
    }
    
    # Test NewCommand method directly
    Write-Host "`nTesting NewCommand method..." -ForegroundColor Cyan
    try {
        # Mock ScreenManager for the test
        $global:ScreenManager = [PSCustomObject]@{
            GetScreen = { return $null }
            RegisterScreen = { }
            PushScreen = { 
                param($screen)
                Write-Host "  ✓ PushScreen called with: $($screen.GetType().Name)" -ForegroundColor Green
            }
        }
        
        $screen.NewCommand()
        Write-Host "  ✓ NewCommand executed successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ NewCommand failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green
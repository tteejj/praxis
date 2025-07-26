#!/usr/bin/env pwsh

# Debug shortcut issue with CommandLibraryScreen
Write-Host "Debugging CommandLibraryScreen shortcuts..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    
    # Check screen type name
    $screenTypeName = $screen.GetType().Name
    Write-Host "Screen type name: '$screenTypeName'" -ForegroundColor Cyan
    
    # Check registered shortcuts
    $shortcutManager = $global:ServiceContainer.GetService('ShortcutManager')
    $shortcuts = $shortcutManager.GetShortcuts([ShortcutScope]::Screen, "CommandLibraryScreen")
    
    Write-Host "`nShortcuts registered for 'CommandLibraryScreen':" -ForegroundColor Yellow
    foreach ($shortcut in $shortcuts) {
        Write-Host "  $($shortcut.Id): '$($shortcut.KeyChar)' -> $($shortcut.Name)" -ForegroundColor Cyan
    }
    
    # Test if ShortcutManager would find these shortcuts
    Write-Host "`nTesting shortcut matching..." -ForegroundColor Yellow
    $nKey = [System.ConsoleKeyInfo]::new('n', [System.ConsoleKey]::N, $false, $false, $false)
    
    # Simulate what ScreenManager would pass
    $handled = $shortcutManager.HandleKeyPress($nKey, $screenTypeName, "")
    Write-Host "Key 'n' handled by ShortcutManager: $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    
    # Check if there are conflicting shortcuts
    $allShortcuts = $shortcutManager.GetAllShortcuts()
    $nShortcuts = $allShortcuts | Where-Object { $_.KeyChar -eq 'n' }
    
    Write-Host "`nAll shortcuts with key 'n':" -ForegroundColor Yellow
    foreach ($shortcut in $nShortcuts) {
        Write-Host "  $($shortcut.Id): Scope=$($shortcut.Scope) ScreenType='$($shortcut.ScreenType)' Priority=$($shortcut.Priority)" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green
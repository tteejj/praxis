#!/usr/bin/env pwsh

# Test CommandLibraryScreen HandleScreenInput method
Write-Host "Testing CommandLibraryScreen HandleScreenInput..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    $screen.SetBounds(0, 0, 80, 25)
    
    # Test HandleScreenInput method
    Write-Host "Testing HandleScreenInput method..." -ForegroundColor Yellow
    
    # Test 'n' key
    $nKey = [System.ConsoleKeyInfo]::new('n', [System.ConsoleKey]::N, $false, $false, $false)
    $handled = $screen.HandleScreenInput($nKey)
    Write-Host "HandleScreenInput('n') returned: $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    
    # Test 'e' key  
    $eKey = [System.ConsoleKeyInfo]::new('e', [System.ConsoleKey]::E, $false, $false, $false)
    $handled = $screen.HandleScreenInput($eKey)
    Write-Host "HandleScreenInput('e') returned: $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    
    # Test 'd' key
    $dKey = [System.ConsoleKeyInfo]::new('d', [System.ConsoleKey]::D, $false, $false, $false)
    $handled = $screen.HandleScreenInput($dKey)
    Write-Host "HandleScreenInput('d') returned: $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    
    # Test full HandleInput flow (should try child first, then screen shortcuts)
    Write-Host "`nTesting full HandleInput flow..." -ForegroundColor Yellow
    
    # First, child (SearchableListBox) should NOT handle n/e/d
    $childHandled = $screen.CommandList.HandleInput($nKey)
    Write-Host "Child CommandList.HandleInput('n'): $childHandled" -ForegroundColor $(if (-not $childHandled) { "Green" } else { "Red" })
    
    # Then, screen HandleInput should handle it via shortcuts
    $screenHandled = $screen.HandleInput($nKey)
    Write-Host "Screen HandleInput('n'): $screenHandled" -ForegroundColor $(if ($screenHandled) { "Green" } else { "Red" })
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green
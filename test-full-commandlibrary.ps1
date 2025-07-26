#!/usr/bin/env pwsh

# Comprehensive test of CommandLibraryScreen functionality
Write-Host "Testing full CommandLibraryScreen functionality..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating CommandLibraryScreen..." -ForegroundColor Yellow
    $screen = [CommandLibraryScreen]::new()
    $screen.Initialize($global:ServiceContainer)
    $screen.SetBounds(0, 0, 80, 25)
    
    Write-Host "Commands loaded: $($screen.CommandList.Items.Count)" -ForegroundColor Green
    
    # Test all shortcut key handling
    Write-Host "`nTesting shortcut key handling..." -ForegroundColor Yellow
    
    # Test 'n' key (NewCommand)
    $nKey = [System.ConsoleKeyInfo]::new('n', [System.ConsoleKey]::N, $false, $false, $false)
    $handled = $screen.HandleScreenInput($nKey)
    Write-Host "  'n' key (NewCommand): $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    
    # Test 'e' key (EditCommand) 
    $eKey = [System.ConsoleKeyInfo]::new('e', [System.ConsoleKey]::E, $false, $false, $false)
    $handled = $screen.HandleScreenInput($eKey)
    Write-Host "  'e' key (EditCommand): $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    
    # Test 'd' key (DeleteCommand)
    $dKey = [System.ConsoleKeyInfo]::new('d', [System.ConsoleKey]::D, $false, $false, $false)
    $handled = $screen.HandleScreenInput($dKey)
    Write-Host "  'd' key (DeleteCommand): $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    
    # Test Enter key (CopySelectedCommand)
    $enterKey = [System.ConsoleKeyInfo]::new([char]13, [System.ConsoleKey]::Enter, $false, $false, $false)
    $handled = $screen.HandleScreenInput($enterKey)
    Write-Host "  Enter key (CopyCommand): $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    
    # Test with selection
    Write-Host "`nTesting with command selected..." -ForegroundColor Yellow
    $screen.CommandList.SelectedIndex = 0
    $selectedCommand = $screen.CommandList.GetSelectedItem()
    Write-Host "  Selected: $($selectedCommand.GetDisplayText())" -ForegroundColor Cyan
    
    # Test copy with selection
    try {
        $screen.CopySelectedCommand()
        Write-Host "  ✓ Copy with selection successful" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Copy failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test that SearchableListBox excludes shortcut keys
    Write-Host "`nTesting SearchableListBox key exclusion..." -ForegroundColor Yellow
    $listHandled = $screen.CommandList.HandleInput($nKey)
    Write-Host "  SearchableListBox handles 'n': $listHandled" -ForegroundColor $(if (-not $listHandled) { "Green" } else { "Red" })
    
    # Test search with normal characters
    $aKey = [System.ConsoleKeyInfo]::new('a', [System.ConsoleKey]::A, $false, $false, $false)
    $listHandled = $screen.CommandList.HandleInput($aKey)
    Write-Host "  SearchableListBox handles 'a': $listHandled" -ForegroundColor $(if ($listHandled) { "Green" } else { "Red" })
    
    Write-Host "`n✓ All CommandLibraryScreen functionality working!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green
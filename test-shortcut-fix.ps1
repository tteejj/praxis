#!/usr/bin/env pwsh

# Test SearchableListBox shortcut key exclusion
Write-Host "Testing SearchableListBox shortcut key exclusion..." -ForegroundColor Cyan

# Load framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

try {
    Write-Host "Creating SearchableListBox..." -ForegroundColor Yellow
    $listBox = [SearchableListBox]::new()
    $listBox.SetItems(@("Item 1", "Item 2", "Item 3"))
    
    Write-Host "ExcludedSearchKeys: $($listBox.ExcludedSearchKeys -join ', ')" -ForegroundColor Cyan
    
    # Test excluded keys
    $excludedKeys = @('n', 'e', 'd')
    foreach ($keyChar in $excludedKeys) {
        $key = [System.ConsoleKeyInfo]::new($keyChar, [System.ConsoleKey]::($keyChar.ToString().ToUpper()), $false, $false, $false)
        $handled = $listBox.HandleInput($key)
        
        Write-Host "Key '$keyChar' handled by SearchableListBox: $handled" -ForegroundColor $(if (-not $handled) { "Green" } else { "Red" })
        Write-Host "  Search mode active: $($listBox._searchMode)" -ForegroundColor Cyan
        Write-Host "  Search query: '$($listBox.SearchQuery)'" -ForegroundColor Cyan
    }
    
    # Test non-excluded key
    Write-Host "`nTesting non-excluded key 's'..." -ForegroundColor Yellow
    $sKey = [System.ConsoleKeyInfo]::new('s', [System.ConsoleKey]::S, $false, $false, $false)
    $handled = $listBox.HandleInput($sKey)
    
    Write-Host "Key 's' handled by SearchableListBox: $handled" -ForegroundColor $(if ($handled) { "Green" } else { "Red" })
    Write-Host "  Search mode active: $($listBox._searchMode)" -ForegroundColor Cyan
    Write-Host "  Search query: '$($listBox.SearchQuery)'" -ForegroundColor Cyan
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed!" -ForegroundColor Green
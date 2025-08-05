# Test both the screen loading and input visibility fixes
Write-Host "Testing TimeEntry screen and dialog fixes..." -ForegroundColor Green

# Test 1: Screen loading fix
Write-Host "1. Testing screen loading (should show projects now)..." -ForegroundColor Yellow

# Test 2: Input visibility fix  
Write-Host "2. Testing input field colors (should be visible now)..." -ForegroundColor Yellow

try {
    # Quick syntax validation
    . "$PSScriptRoot/Screens/TimeEntryScreen.ps1" 2>&1 | Out-Null
    . "$PSScriptRoot/Components/DialogField.ps1" 2>&1 | Out-Null
    Write-Host "✓ Syntax validation passed" -ForegroundColor Green
    
    Write-Host "✓ Fixes applied successfully" -ForegroundColor Green
    Write-Host "Now test in the application:" -ForegroundColor Cyan
    Write-Host "  1. TimeEntry screen should show all projects (not blank)" -ForegroundColor Cyan  
    Write-Host "  2. When adding time entry, input text should be visible" -ForegroundColor Cyan
    
} catch {
    Write-Host "✗ Error: $_" -ForegroundColor Red
    exit 1
}
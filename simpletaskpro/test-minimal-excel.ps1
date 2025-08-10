#!/usr/bin/env pwsh
# test-minimal-excel.ps1 - Test minimal Excel functionality

Write-Host "Testing minimal Excel functionality..." -ForegroundColor Cyan

try {
    # Start SimpleTaskPro and immediately test F6 Excel navigation
    Write-Host "This test will:"  -ForegroundColor Yellow
    Write-Host "1. Start SimpleTaskPro" -ForegroundColor Gray
    Write-Host "2. You should press F6 to open Excel screen" -ForegroundColor Gray  
    Write-Host "3. Try F1-F9 functions on Excel screen" -ForegroundColor Gray
    Write-Host "4. Press F10 to return to tasks" -ForegroundColor Gray
    Write-Host "5. Press ESC to quit the application" -ForegroundColor Gray
    Write-Host ""
    
    Read-Host "Press Enter to start test (or Ctrl+C to cancel)"
    
    # Launch SimpleTaskPro
    ./SimpleTaskPro.ps1
    
} catch {
    Write-Host "Test failed: $_" -ForegroundColor Red
}
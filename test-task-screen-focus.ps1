#!/usr/bin/env pwsh
# Test script for TaskScreen focus and CRUD operations

Write-Host "Testing TaskScreen focus and CRUD operations..." -ForegroundColor Cyan
Write-Host ""
Write-Host "This test will:" -ForegroundColor Yellow
Write-Host "1. Switch to the Tasks tab"
Write-Host "2. Verify the DataGrid has focus (you should be able to navigate with arrow keys)"
Write-Host "3. Test CRUD operations:"
Write-Host "   - Press 'n' to create a new task"
Write-Host "   - Press 'e' or Enter to edit a task"
Write-Host "   - Press 'd' to delete a task"
Write-Host "   - Press 's' to cycle task status"
Write-Host "   - Press 'p' to cycle task priority"
Write-Host ""
Write-Host "After each dialog closes, focus should return to the DataGrid automatically."
Write-Host ""
Write-Host "Press any key to start the test..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

# Run the application
& "$PSScriptRoot/Start.ps1"
Write-Host "Launching PRAXIS to test visual fixes..." -ForegroundColor Green
Write-Host "Look for:" -ForegroundColor Yellow
Write-Host "  • Left panel should NOT have grey background" -ForegroundColor Gray
Write-Host "  • DataGrid on projects screen should NOT have grey rows" -ForegroundColor Gray  
Write-Host "  • New Projects dialog should use proper layout" -ForegroundColor Gray
Write-Host "  • Press 'n' on projects screen to test dialog" -ForegroundColor Gray
Write-Host "  • Press Ctrl+Q to exit" -ForegroundColor Gray
Write-Host ""

pwsh -File Start.ps1
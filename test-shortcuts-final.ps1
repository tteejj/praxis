#!/usr/bin/env pwsh
# Final test to verify shortcuts are working

Write-Host "`nShortcut System Test" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

# Clear log
if (Test-Path "_Logs/praxis.log") {
    Clear-Content "_Logs/praxis.log"
}

Write-Host @"
Testing the shortcut system with the case-insensitive fix applied.

Instructions:
1. Navigate to Projects screen (press 1)
2. Try these shortcuts:
   - e: Edit project
   - d: Delete project
   - n: New project
   - Ctrl+Right Arrow: Next focus
   - Ctrl+Left Arrow: Previous focus

3. Navigate to Tasks screen (press 2)
4. Try shortcuts there too

The shortcuts should now work properly!
"@ -ForegroundColor Yellow

Write-Host "`nStarting PRAXIS..." -ForegroundColor Green

# Run PRAXIS
pwsh -File Start.ps1
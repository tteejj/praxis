#!/usr/bin/env pwsh
# Comprehensive shortcut debugging

Write-Host "`nComprehensive Shortcut Debug" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

Write-Host @"
This test will show:
- [REG] When shortcuts are registered  
- [UNREG] When shortcuts are unregistered
- [DEBUG] Each key press
- [SM] ShortcutManager processing
- [MATCH] When keys match shortcuts
- Screen activation messages

Test Plan:
1. Start on MainScreen
2. Press 1 to go to Projects - should see OnActivated
3. Press 'e' - should see matching and handling
4. Press 2 to go to Tasks  
5. Press 'e' again

Watch the output carefully!
"@ -ForegroundColor Yellow

Write-Host "`nStarting PRAXIS..." -ForegroundColor Green
Write-Host ""

# Run PRAXIS
pwsh -File Start.ps1
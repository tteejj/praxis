#!/usr/bin/env pwsh
# Debug shortcut issues

Write-Host "`nDebugging Shortcuts and Focus" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

Write-Host @"
This will show debug output for:
- Shortcut registration/unregistration
- Key handling
- Focus changes

Watch for:
[REG] = Shortcut registered
[UNREG] = Shortcut unregistered  
[DEBUG] = Key press info
[SM] = ShortcutManager processing

Navigate between screens and press 'e' or 'd' to test.
"@ -ForegroundColor Yellow

Write-Host "`nStarting PRAXIS with debug output..." -ForegroundColor Green

# Run PRAXIS
pwsh -File Start.ps1
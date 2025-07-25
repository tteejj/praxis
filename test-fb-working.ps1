#!/usr/bin/env pwsh
# Test if file browser is working

Write-Host @"
==================================
FILE BROWSER TEST
==================================
Instructions:
1. Press '3' to open file browser
2. Use vim keys to navigate:
   - j/k: up/down
   - h/l: parent/enter directory
3. Look for green highlight on selected item
4. Press ESC to go back to main menu
5. Press Ctrl+C to exit

Starting PRAXIS...
"@ -ForegroundColor Cyan

& ./Start.ps1
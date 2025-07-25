#!/usr/bin/env pwsh
# Test time entry screen

Write-Host @"
==================================
TIME ENTRY SCREEN TEST
==================================
Instructions:
1. Press '3' to open time entry screen
2. You should see time entries for the current week
3. Press 'q' to open Quick Entry dialog
4. Press 'e' to edit selected entry
5. Use arrow keys to navigate weeks
6. Press Ctrl+Q to exit

Starting PRAXIS...
"@ -ForegroundColor Cyan

& ./Start.ps1
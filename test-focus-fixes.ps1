#!/usr/bin/env pwsh
# Test focus fixes - run with debug logging enabled

Write-Host @"
================================================================================
FOCUS & CRUD FIXES TEST
================================================================================

This test runs PRAXIS with debug logging to verify:
1. Focus is set when switching tabs (check logs)
2. DataGrids show highlighted rows
3. CRUD operations work with keyboard

WHAT TO TEST:
-------------
1. Switch to Tasks tab (Alt+2)
   - Should see a highlighted row immediately
   - Arrow keys should work right away
   - Check log for "Container.FocusFirst" and "FocusManager.SetFocus"

2. Test CRUD operations:
   - 'n' for new task (should work now!)
   - 'e' to edit
   - 'd' to delete
   - After dialog closes, focus should return to grid

3. Switch to other tabs and verify:
   - Projects (Alt+1) - should have highlighted row
   - Time Entry (Alt+3) - should have highlighted row

Watch the logs for focus-related messages!
Press any key to start with debug logging...
"@ -ForegroundColor Cyan

$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

# Run with debug flag to see focus logging
& "$PSScriptRoot/Start.ps1" -Debug
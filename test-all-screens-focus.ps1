#!/usr/bin/env pwsh
# Comprehensive test for focus and CRUD operations across all screens

Write-Host @"
================================================================================
ALL SCREENS FOCUS & CRUD TEST
================================================================================

This test verifies:
1. Focus is automatically set when switching to each screen
2. CRUD operations work with keyboard shortcuts
3. Focus returns after dialogs close

TESTING CHECKLIST:
-----------------

PROJECTS SCREEN (Alt+1):
[ ] DataGrid has focus on switch (arrow keys work immediately)
[ ] 'n' - Creates new project
[ ] 'e' or Enter - Edits selected project  
[ ] 'd' - Deletes selected project
[ ] Focus returns to grid after dialog

TASKS SCREEN (Alt+2):
[ ] DataGrid has focus on switch (arrow keys work immediately)
[ ] 'n' - Creates new task
[ ] 'e' or Enter - Edits selected task
[ ] 'd' - Deletes selected task
[ ] 's' - Cycles task status
[ ] 'p' - Cycles task priority
[ ] 'a' - Adds subtask
[ ] Focus returns to grid after dialog

TIME ENTRY SCREEN (Alt+3):
[ ] DataGrid has focus on switch (arrow keys work immediately)
[ ] 'q' - Quick time entry
[ ] 'n' - New time entry
[ ] 'e' - Edit selected entry
[ ] 'd' - Delete selected entry
[ ] Left/Right arrows - Navigate weeks
[ ] Focus returns to grid after dialog

Press any key to start...
"@ -ForegroundColor Cyan

$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

# Run the application
& "$PSScriptRoot/Start.ps1"
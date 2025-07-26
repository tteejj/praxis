#!/usr/bin/env pwsh
# Simple test to verify dialog keyboard shortcuts

Write-Host @"
Testing Dialog Keyboard Shortcuts
=================================

Instructions:
1. Run: pwsh Start.ps1
2. On Projects tab (press 1), test these keys:
   - N: Should open New Project dialog
   - E: Should open Edit Project dialog (select a project first)
   - D: Should open Delete confirmation dialog

3. On Tasks tab (press 2), test these keys:
   - N: Should open New Task dialog
   - E: Should open Edit Task dialog (select a task first)
   - D: Should open Delete confirmation dialog
   - Shift+A: Should open Add Subtask dialog

4. In any dialog:
   - Tab/Shift+Tab: Should navigate between fields
   - All text boxes should have rounded borders
   - Escape: Should close dialog

All dialogs should:
- Have rounded borders
- Support Tab navigation between fields
- Have MinimalTextBox with rounded borders
- Not throw any VT method errors

"@ -ForegroundColor Cyan

Read-Host "Press Enter to start the application..."
pwsh Start.ps1
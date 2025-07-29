#!/usr/bin/env pwsh

# Fix script for dialog issues

Write-Host "Dialog Issues Analysis and Fixes" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow

Write-Host "`nIssues Identified:" -ForegroundColor Red
Write-Host "1. Dialogs not displaying properly - may be off-screen"
Write-Host "2. Text entry not working - focus issues"
Write-Host "3. Tab navigation broken - controls not properly registered"
Write-Host "4. ESC key not working - input handling issue"
Write-Host "5. Row highlighting not visible after ESC"

Write-Host "`nRoot Causes:" -ForegroundColor Cyan
Write-Host "1. Dialog centering calculation may place dialog off-screen if terminal is small"
Write-Host "2. Focus manager not properly setting focus on text boxes"
Write-Host "3. Tab navigation requires proper TabIndex and focus management"
Write-Host "4. BaseDialog may be intercepting ESC before it reaches the parent screen"

Write-Host "`nRequired Fixes:" -ForegroundColor Green
Write-Host "1. Add bounds checking to dialog positioning"
Write-Host "2. Ensure text boxes are focusable and properly initialized"
Write-Host "3. Fix tab order in dialogs"
Write-Host "4. Fix ESC key handling to properly close dialog and restore parent focus"
Write-Host "5. Ensure parent screen refreshes after dialog closes"

Write-Host "`nFiles to modify:"
Write-Host "- Base/BaseDialog.ps1 - Fix positioning and focus"
Write-Host "- Components/MinimalTextBox.ps1 - Ensure focusable"
Write-Host "- Services/FocusManager.ps1 - Fix focus restoration"
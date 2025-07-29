# CRUD Fixes Summary

## Issues Fixed

### 1. Create/Save Not Working
**Problem**: Method invocation failed - ProjectService had no `SaveProject` method
**Fix**: Changed `SaveProject()` to `UpdateProject()` in NewProjectDialog.ps1 (line 115)

### 2. Highlight Covering Text in Grids
**Problem**: Selected row colors were not being reset, causing text to be invisible
**Fix**: Added `[VT]::Reset()` after each row render in MinimalDataGrid.ps1 to prevent color bleed

### 3. Text Input Not Visible in Dialogs
**Problems**:
- Background fill was covering text
- Text color might not be set properly

**Fixes Applied**:
1. Removed background fill in MinimalTextBox - dialogs already provide background
2. Added check to ensure text color is set if missing
3. Added color reset after rendering to prevent bleed

## Result
- Project creation now saves properly
- Grid rows display correctly with visible text when selected
- Text input in dialogs is now visible as you type

## Additional Notes
The key issue was color management - colors were not being reset properly, causing:
- Background colors to bleed into text areas
- Selected row colors to persist and hide text
- Text boxes to render with same color background and foreground

All components now properly reset colors after rendering.
# Time Entry Improvements Summary

## Changes Made

### 1. Added Time Entry Options Dialog
Created `TimeEntryOptionsDialog.ps1` that presents two options when creating a new time entry:
- **Select from existing projects** - Shows the project selection dialog
- **Enter ID2 manually** - For non-project time entries (ADM, TRN, VAC, etc.)

### 2. Added Manual Time Entry Dialog
Created `ManualTimeEntryDialog.ps1` that allows users to:
- Enter any ID2 code manually
- Provide a description/name for the entry
- Set the date and hours
- Add optional notes
- Works for both project and non-project time tracking

### 3. Fixed SelectionDialog Enter Key
- Modified `SelectionDialog.ps1` to only trigger selection on Enter key
- Removed `OnSelectionChanged` that was firing on arrow key navigation
- Added `HandleScreenInput` override to properly handle Enter key when ListBox has focus

### 4. Updated Time Entry Flow
Modified `TimeEntryScreen.ps1` `NewTimeEntry()` method to:
1. First show the options dialog
2. Based on selection:
   - Show project selection for existing projects
   - Show manual entry dialog for custom ID2 codes

## How to Use

1. **Navigate to Time Entry** - Press `3`
2. **Create New Entry** - Press `n`
3. **Choose Entry Method**:
   - Use arrow keys to select between project selection or manual entry
   - Press Enter to confirm choice
4. **For Project Selection**:
   - Navigate with arrow keys through project list
   - Press Enter to select a project
   - Fill in date, hours, and description
5. **For Manual Entry**:
   - Enter the ID2 code (e.g., ADM, TRN, VAC)
   - Enter a description
   - Fill in date and hours
   - Add optional notes

## Benefits

- Users can now track both project and non-project time
- Manual entry supports any ID2 code without requiring it to be a project
- Enter key properly selects items in lists (no more auto-selection on navigation)
- Clear separation between project-based and administrative time tracking
# Dialog Fixes Summary

## Issues Fixed

### 1. Dialogs Not Displaying Properly
**Problem**: Dialogs were being centered but could appear off-screen on small terminals.
**Fix**: Added bounds checking in `BaseDialog.OnBoundsChanged()` to ensure dialogs stay within terminal bounds.

### 2. Text Entry Not Working
**Problem**: Text boxes weren't receiving focus when dialogs opened.
**Fix**: 
- Enhanced `BaseDialog.OnActivated()` to properly use FocusManager
- Added call to `OnBoundsChanged()` to ensure proper positioning
- Added `Invalidate()` call to force cursor display

### 3. Tab Navigation Between Fields
**Problem**: Tab key wasn't moving between dialog fields.
**Fix**: The existing Container class already handles tab navigation properly. The fix to focus initialization resolved this.

### 4. ESC Key and Row Highlighting
**Problem**: After pressing ESC, the parent screen wasn't refreshing properly.
**Fix**: Modified `BaseDialog.CloseDialog()` to:
- Get reference to parent screen before popping
- Force parent to invalidate and re-activate after dialog closes
- This ensures row highlighting and focus are restored

### 5. Nickname Property Removal
**Removed from**:
- `Models/Project.ps1` - Removed property and updated constructors
- `Screens/NewProjectDialog.ps1` - Removed nickname field
- `Screens/EditProjectDialog.ps1` - Removed nickname field  
- `Services/ProjectService.ps1` - Updated all methods to use FullProjectName only

## Result
- All CRUD dialogs now display properly within terminal bounds
- Text entry works immediately when dialogs open
- Tab key navigates between fields
- ESC key properly closes dialogs and restores parent state
- Project nickname is completely removed from the codebase

## Testing
1. Press 'n' in Projects screen to create new project
2. Press 'e' to edit existing project
3. Use Tab to move between fields
4. Press ESC to cancel - verify row highlight returns
5. Create/edit tasks and other entities to verify all dialogs work
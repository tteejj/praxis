# Fixes Applied to PRAXIS - 2025-07-22

## 1. Button Layout Fixes (from ROADMAP)

Applied consistent button positioning logic from ProjectsScreen to all dialogs:

### Files Modified:
- `Screens/NewProjectDialog.ps1`
- `Screens/NewTaskDialog.ps1`
- `Screens/EditTaskDialog.ps1`
- `Screens/ConfirmationDialog.ps1`

### Changes:
- Moved button positioning to `OnBoundsChanged()` method
- Added consistent button sizing: height=3, spacing=2
- Implemented responsive button width calculation
- Added dark overlay rendering (RGB 16,16,16) for all dialogs

## 2. Null Reference Fixes in TaskScreen

Fixed callback closures that were incorrectly accessing `$this`:

### File Modified:
- `Screens/TaskScreen.ps1`

### Changes in Methods:
- `NewTask()`: Added `$screen = $this` capture
- `EditTask()`: Added `$screen = $this` and `$task = $selected` captures
- `DeleteTask()`: Added `$screen = $this` and `$taskId = $selected.Id` captures

## 3. Project Constructor Fix

Fixed incorrect usage of parameterless Project constructor:

### Files Modified:
- `Components/CommandPalette.ps1`
- `Screens/ProjectsScreen.ps1`

### Changes:
- Changed from `[Project]::new()` to `ProjectService.AddProject()`
- Updated ProjectsScreen to use NewProjectDialog instead of test projects
- Added proper nickname generation from project name

## 4. Module Loading Order Fix

Fixed type loading errors by reordering module loads:

### File Modified:
- `Start.ps1`

### Changes:
- Moved all dialog classes before screens that use them
- Added clear comments about load order dependencies

## Testing

Created test scripts to verify all fixes:
- `test-button-fixes.ps1` - Verifies button layout fixes
- `test-new-task-fix.ps1` - Verifies null reference fixes
- `test-project-constructor-fix.ps1` - Verifies constructor fixes

All tests pass successfully.
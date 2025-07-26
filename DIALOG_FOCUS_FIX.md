# Dialog Focus Fix Summary

## Issues Identified

1. **Dialog borders overlapping with textbox borders** ✅ FIXED
   - Set `ShowBorder = $false` on all MinimalTextBox instances in dialogs
   - Set `Height = 1` instead of 3 for textboxes
   - Adjusted dialog positioning to use 2-line spacing

2. **Focus not visible** 🔧 IN PROGRESS
   - MinimalTextBox shows cursor when focused (▌ character)
   - Border color changes when focused
   - Need to verify FocusManager is working

3. **Tab navigation not working** 🔧 IN PROGRESS
   - Added Tab handling to Container base class
   - Uses FocusManager.FocusNext/Previous
   - Removed duplicate handling from BaseDialog

## Changes Made

### NewProjectDialog.ps1
```powershell
# Disabled textbox borders
$this.NameBox.ShowBorder = $false
$this.NameBox.Height = 1

# Reduced dialog height
$this.DialogHeight = 26  # Was 36

# Updated positioning to use 1-line height + 1 spacing
$currentY += 2  # Was += 3
```

### Container.ps1
```powershell
# Added Tab navigation handling
if ($key.Key -eq [System.ConsoleKey]::Tab) {
    if ($focusManager) {
        if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
            [void]$focusManager.FocusPrevious($this)
        } else {
            [void]$focusManager.FocusNext($this)
        }
        $this.Invalidate()
        return $true
    }
}
```

### BaseDialog.ps1
- Removed HandleInput override since Container now handles Tab

## Still To Fix

1. **Verify focus is actually being set**
   - Check if FocusManager.SetFocus is being called
   - Ensure focused element shows cursor
   - Test Tab navigation works

2. **Fix other dialogs**
   - Apply same ShowBorder/Height fixes to all dialogs
   - EditProjectDialog
   - EditTaskDialog
   - TimeEntryDialog
   - QuickTimeEntryDialog
   - All other dialogs using MinimalTextBox

## Testing

To test if focus is working:
1. Press N in Projects screen to open NewProjectDialog
2. First textbox should show cursor (▌)
3. Press Tab - focus should move to next field
4. Press Shift+Tab - focus should move back
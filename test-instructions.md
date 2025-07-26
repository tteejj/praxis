# Test Instructions for VisualMacroFactoryScreen

The VisualMacroFactoryScreen is working correctly from a code perspective. The issue appears to be a rendering problem.

## What to Test:

1. Start PRAXIS: `pwsh -File Start.ps1`
2. Press `7` to go to the Macro Factory tab
3. Look for these expected items in the left pane:
   - 📊 Summarization
   - ⚙️ Append Calculated Field  
   - 📋 Export to Excel
   - 🔧 Custom IDEA@ Command

## Code Status:
- ✅ Actions load correctly (4 items)
- ✅ ComponentLibrary populated (4 items)
- ✅ SearchableListBox has data (4 filtered items)
- ✅ Bounds calculation works (36x28 left pane)
- ✅ All components initialize properly

## If "No items found" still appears:
The issue is in the **rendering pipeline**, not the data loading. The data is definitely there.

Possible causes:
1. SearchableListBox rendering issue with specific bounds
2. TabContainer child rendering problem  
3. Theme/color rendering interference
4. VT100 sequence corruption

The fix applied makes VisualMacroFactoryScreen follow the exact same pattern as CommandLibraryScreen.
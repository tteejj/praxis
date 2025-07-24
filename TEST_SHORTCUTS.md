# Manual Test Instructions for Screen Shortcuts

## Current Status:
- **ShortcutManager is properly integrated** - Centralized shortcut management
- **Shortcuts are registered** but may not be working due to case sensitivity or other issues

## To test if shortcuts are working:

1. Run: `pwsh -File Start.ps1`

2. Test these shortcuts:
   - Press `1` to go to Projects tab
   - Press `n` (lowercase) - Should open New Project dialog
   - Press `e` (lowercase) - Should open Edit Project dialog (if a project is selected)
   - Press `q` to quit dialogs
   
3. Test FileBrowser focus (Tab 3):
   - Press `3` to go to Files tab
   - Look for blue border around file tree (indicates focus)
   - Use arrow keys to navigate files
   
4. Check the logs for debugging:
   - Look for these key entries in _Logs/praxis.log:
     - "ShortcutManager.HandleKeyPress" - Shows what key was pressed
     - "ProjectsScreen.RegisterShortcuts" - Confirms shortcuts were registered
     - "ShortcutManager: Total shortcuts registered" - Shows count
     - "Screen shortcut matches" - Shows if shortcut was found

## What was fixed:
1. Removed Dashboard screen (was causing issues)
2. ShortcutManager now properly detects active tab content (ProjectsScreen, etc.)
3. All screens have OnActivated methods for proper focus
4. FileBrowser is now tab 3 (was 4)
5. Added extensive debug logging to trace shortcut issues

## Architecture:
- ScreenManager checks ShortcutManager first for all keys
- ShortcutManager uses scope-based shortcuts (Global, Screen, Context)
- ProjectsScreen registers its shortcuts ('n', 'e', 'd') when initialized
- Shortcuts are case-sensitive (lowercase 'n', not 'N')
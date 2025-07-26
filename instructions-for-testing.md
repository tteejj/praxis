# Testing CommandLibraryScreen Shortcuts

I've added logging to the CommandLibraryScreen methods. To test if the shortcuts are working:

## Test Steps:
1. Start PRAXIS: `pwsh -File Start.ps1 -Debug`
2. Press `6` to go to Commands tab
3. Try pressing:
   - `n` for New Command
   - `e` for Edit Command (with a command selected)
   - `d` for Delete Command (with a command selected)

## Check Logs:
After testing, check the logs for these messages:
```bash
tail -20 /home/teej/projects/github/praxis/_Logs/praxis.log | grep -E "(NewCommand|EditCommand|DeleteCommand)"
```

## Expected Log Messages:
- `CommandLibraryScreen.NewCommand: Called via shortcut`
- `CommandLibraryScreen.EditCommand: Called via shortcut`
- `CommandLibraryScreen.DeleteCommand: Called via shortcut`

If these messages appear, the shortcuts are working and the issue is in the dialog system.
If they don't appear, the shortcuts aren't reaching the CommandLibraryScreen methods.

## Status:
- ✅ Cursor navigation works (Up/Down arrows)
- ✅ Commands display correctly (5 default commands)
- ✅ Focus management works
- ❓ Keyboard shortcuts (n, e, d) - testing needed
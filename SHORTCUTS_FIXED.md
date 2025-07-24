# Shortcuts Fixed!

The shortcuts now work exactly like the CommandPalette - using EventBus to publish commands that screens listen for.

## How it works:

1. **ShortcutManager** now simply:
   - Checks which screen is active
   - Maps key presses to commands (e.g., 'e' → 'EditProject')
   - Publishes CommandExecuted events via EventBus

2. **Screens** already had EventBus subscriptions that listen for these commands
   - ProjectsScreen listens for: NewProject, EditProject, DeleteProject, etc.
   - TaskScreen listens for: NewTask, EditTask, DeleteTask, etc.
   - FileBrowserScreen listens for: EditFile, ViewFile, NavigateUp

3. **No complex registration needed** - just like CommandPalette!

## Available shortcuts:

### Projects Screen (1)
- **n** - New project
- **e** - Edit selected project
- **d** - Delete selected project
- **r** - Refresh project list
- **v** - View project details

### Tasks Screen (2)
- **n** - New task
- **e** - Edit selected task
- **d** - Delete selected task
- **r** - Refresh task list
- **a** - Add subtask
- **s** - Cycle task status
- **p** - Cycle task priority

### File Browser (4)
- **e** - Edit selected file
- **v** - View selected file
- **u** - Navigate up directory

## Test it:
```bash
pwsh -File Start.ps1
```

Press 1 for Projects, then press 'e' - it will edit the selected project!
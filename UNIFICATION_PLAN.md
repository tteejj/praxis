# Praxis Apps Unification Plan

## Current State
- 5 standalone apps: TaskPro, TimeTracker, CommandLibrary, MacroFactory, ExcelDataFlow
- Each has its own UI components, services, and data storage
- No inter-app communication

## Unification Goals
1. Share common components (reduce duplication)
2. Enable data exchange between apps
3. Consistent user experience
4. Maintain standalone functionality

## Phase 1: Common Core (Week 1)
Create PraxisCore directory with shared components:

### Shared Components to Extract:
- **VT100.ps1** - Already duplicated in all apps
- **SimpleList.ps1** - Pillbox list component
- **SimpleDialog.ps1** - Standard dialogs
- **Logger.ps1** - Unified logging

### Implementation:
```powershell
# Each app adds at start:
. "$PSScriptRoot/../PraxisCore/UI/VT100.ps1"
. "$PSScriptRoot/../PraxisCore/Services/Logger.ps1"
```

## Phase 2: Data Exchange (Week 2)

### Standard Data Format:
```json
{
  "source": "TaskPro",
  "type": "tasks",
  "version": "1.0",
  "timestamp": "2024-01-15T10:30:00",
  "data": [...]
}
```

### Exchange Methods:
1. **File-based**: Apps write to `~/.praxis/exchange/`
2. **Direct calls**: `taskpro --export | timetracker --import`
3. **Shared database**: SQLite for common data

## Phase 3: Integration Features (Week 3)

### Quick Wins:
1. **TaskPro → TimeTracker**: "Track Time" button opens TimeTracker with task
2. **TimeTracker → ExcelDataFlow**: Export weekly timesheet
3. **CommandLibrary → MacroFactory**: Convert commands to macro actions
4. **MacroFactory → CommandLibrary**: Save macros as reusable commands

### Implementation Pattern:
```powershell
# In TaskPro
if (Test-Path "../TimeTracker/TimeTracker.ps1") {
    $trackTimeButton.Enabled = $true
    $trackTimeButton.OnClick = {
        $task | ConvertTo-Json | Set-Content ~/.praxis/exchange/current-task.json
        & "../TimeTracker/TimeTracker.ps1" --from-task
    }
}
```

## Phase 4: Unified Configuration (Week 4)

### Shared Settings:
```json
{
  "theme": "synthwave",
  "fontsize": 14,
  "autosave": true,
  "apps": {
    "taskpro": {"defaultView": "list"},
    "timetracker": {"weekStart": "Monday"}
  }
}
```

### Theme Sharing:
- All apps read from `~/.praxis/theme.json`
- Hot reload when changed

## Quick Implementation Ideas

### 1. Recent Items (1 hour)
```powershell
# ~/.praxis/recent.json
# All apps write to this when opening items
```

### 2. Universal Search (2 hours)
```powershell
# PraxisLauncher.ps1 adds search mode
# Searches across all app data files
```

### 3. Quick Switch (30 minutes)
```powershell
# Global hotkey (Ctrl+Shift+P) returns to launcher
# Last app position saved
```

### 4. Backup All (1 hour)
```powershell
# Single command backs up all app data
./PraxisLauncher.ps1 --backup
```

## Benefits
- **Code Reduction**: ~30% less duplicate code
- **Consistency**: Same UI patterns everywhere  
- **Power Features**: Cross-app workflows
- **Maintenance**: Fix bugs in one place

## Risks & Mitigation
- **Breaking Changes**: Keep old paths as fallbacks
- **Complexity**: Start with simple file exchanges
- **Performance**: Lazy load shared components

## Success Metrics
- All apps still work standalone ✓
- At least 3 integrations implemented
- Shared components used by all apps
- User can flow between apps seamlessly
# SimpleTaskPro Project Management Enhancement Plan

## Overview
Transform SimpleTaskPro into a comprehensive project hub with per-project settings, file browser integration, and external file editing capabilities. Parent tasks become project headers with subtasks as actual work items.

## Current Status
- ✅ Notes system fixed - separate files per parent task  
- ✅ Cursor positioning fixed in both editors and input fields
- ✅ VT100 MoveTo coordinates fixed (was causing cursor lag)

## Implementation Phases

### Phase 1: Settings Foundation & File Browser System

#### 1.1 SimpleTask Model Extensions
**File**: `Models/SimpleTask.ps1`
**Add new properties**:
```powershell
# Project management fields
[string]$ProjectFolderPath = ""      # Path to project folder
[string]$T2020CallLogFile = ""       # Full path to T2020 call log file
[string]$ExportDataFile = ""         # Full path to ExcelDataFlow export file
[string]$ActionLogName = "action-log" # Name of action log file (without extension)

# Display fields for project view
[string]$ID1 = ""                    # Project code (3 chars display)
[string]$ID2 = ""                    # Unique project ID (12 chars display)
# CreatedDate already exists, just need to display it
```

#### 1.2 File Browser Helper Class
**File**: `Core/FileBrowser.ps1` (NEW FILE)
**Purpose**: Native Windows file/folder dialogs
```powershell
class FileBrowser {
    static [string] ShowFolderBrowser([string]$title, [string]$initialDir = "") {
        Add-Type -AssemblyName System.Windows.Forms
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = $title
        if ($initialDir -and (Test-Path $initialDir)) {
            $folderBrowser.SelectedPath = $initialDir
        }
        
        if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $folderBrowser.SelectedPath
        }
        return ""
    }
    
    static [string] ShowFileBrowser([string]$title, [string]$filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*", [string]$initialDir = "") {
        Add-Type -AssemblyName System.Windows.Forms
        $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
        $fileBrowser.Title = $title
        $fileBrowser.Filter = $filter
        if ($initialDir -and (Test-Path $initialDir)) {
            $fileBrowser.InitialDirectory = $initialDir
        }
        
        if ($fileBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $fileBrowser.FileName
        }
        return ""
    }
}
```

#### 1.3 Project Settings Dialog
**File**: `Dialogs/ProjectSettingsDialog.ps1` (NEW FILE)
**Access**: Ctrl+, when parent task selected
**Layout**:
```
┌──────────────── Project Settings ───────────────────┐
│ Project Name: [Complete quarterly report          ] │
│                                                     │
│ Project Folder:  [C:\Projects\Q4Report] [Browse...] │
│                                                     │
│ T2020 Call Log:  [C:\Projects\Q4Report\T2020.txt ] │
│                                        [Browse...]  │
│                                                     │
│ Export Data File:[C:\Projects\Q4Report\export.txt] │
│                                        [Browse...]  │
│                                                     │
│ Action Log Name: [action-log          ]            │
│                                                     │
│ Project Codes:                                      │
│   ID1 (3 chars): [Q4 ]                            │
│   ID2 (12 chars):[RPT-2025-001 ]                  │
│                                                     │
│                        [Save] [Cancel]              │
└─────────────────────────────────────────────────────┘
```

**Validation Logic**:
- Project Folder: Must exist, create if doesn't exist (ask user)
- T2020 Call Log: Must exist if specified, clear if doesn't exist
- Export Data File: Must exist if specified, clear if doesn't exist
- Action Log Name: Text validation, no path separators

**Dialog Implementation**:
```powershell
class ProjectSettingsDialog {
    [SimpleTask]$Task
    [int]$Width = 60
    [int]$Height = 20
    
    [bool] Show([SimpleTask]$task) {
        $this.Task = $task
        # Render dialog, handle input, validate paths
        # Return true if saved, false if cancelled
    }
    
    [void] BrowseProjectFolder() {
        $folder = [FileBrowser]::ShowFolderBrowser("Select Project Folder", $this.Task.ProjectFolderPath)
        if ($folder) { $this.Task.ProjectFolderPath = $folder }
    }
    
    [void] BrowseT2020File() {
        $initialDir = if ($this.Task.ProjectFolderPath) { $this.Task.ProjectFolderPath } else { "" }
        $file = [FileBrowser]::ShowFileBrowser("Select T2020 Call Log", "Text files (*.txt)|*.txt", $initialDir)
        if ($file) { $this.Task.T2020CallLogFile = $file }
    }
    
    [void] BrowseExportFile() {
        $initialDir = if ($this.Task.ProjectFolderPath) { $this.Task.ProjectFolderPath } else { "" }
        $file = [FileBrowser]::ShowFileBrowser("Select Export Data File", "Text files (*.txt)|*.txt", $initialDir)
        if ($file) { $this.Task.ExportDataFile = $file }
    }
    
    [bool] ValidateAndSave() {
        # Validate each path, clear if doesn't exist, save if valid
    }
}
```

### Phase 2: Hotkey Integration & File Operations

#### 2.1 Update TaskListScreen Hotkey Handling
**File**: `Screens/TaskListScreen.ps1`
**Add new hotkeys in HandleInput method**:

```powershell
([System.ConsoleKey]::Comma) {
    if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
        # Ctrl+, - Project Settings
        if ($this.FlatList.Count -gt 0) {
            $item = $this.FlatList[$this.SelectedIndex]
            $parentTask = if ($item.Task.IsParent()) { $item.Task } else { $this.TaskService.GetTask($item.Task.ParentId) }
            if ($parentTask) {
                return $this.OpenProjectSettings($parentTask)
            }
        }
        return $true
    }
}

([System.ConsoleKey]::O) {
    if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
        # Ctrl+O - Open Project Folder
        return $this.OpenProjectFolder()
    }
}

([System.ConsoleKey]::T) {
    if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
        # Ctrl+T - Open T2020 Call Log
        return $this.OpenT2020CallLog()
    }
}

([System.ConsoleKey]::P) {
    if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
        # Ctrl+P - Open Export Data File (read-only)
        return $this.OpenExportDataFile()
    }
}

([System.ConsoleKey]::N) {
    if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
        # Ctrl+N - Open Action Log
        return $this.OpenActionLog()
    }
}
```

#### 2.2 Project File Operation Methods
**Add to TaskListScreen class**:

```powershell
[bool] OpenProjectSettings([SimpleTask]$parentTask) {
    $dialog = [ProjectSettingsDialog]::new()
    if ($dialog.Show($parentTask)) {
        $this.TaskService.UpdateTask($parentTask)
        return $true
    }
    return $true
}

[bool] OpenProjectFolder() {
    $parentTask = $this.GetCurrentParentTask()
    if ($parentTask -and $parentTask.ProjectFolderPath -and (Test-Path $parentTask.ProjectFolderPath)) {
        try {
            Start-Process explorer.exe -ArgumentList $parentTask.ProjectFolderPath
        } catch {
            Write-Warning "Could not open project folder: $_"
        }
    } else {
        Write-Warning "No project folder configured for this project"
    }
    return $true
}

[bool] OpenT2020CallLog() {
    $parentTask = $this.GetCurrentParentTask()
    if ($parentTask -and $parentTask.T2020CallLogFile -and (Test-Path $parentTask.T2020CallLogFile)) {
        return $this.EditExternalFile($parentTask.T2020CallLogFile, "T2020 CALL LOG", $false)
    } else {
        Write-Warning "No T2020 call log file configured or file not found"
    }
    return $true
}

[bool] OpenExportDataFile() {
    $parentTask = $this.GetCurrentParentTask()
    if ($parentTask -and $parentTask.ExportDataFile -and (Test-Path $parentTask.ExportDataFile)) {
        return $this.EditExternalFile($parentTask.ExportDataFile, "EXPORT DATA (READ-ONLY)", $true)
    } else {
        Write-Warning "No export data file configured or file not found"
    }
    return $true
}

[bool] OpenActionLog() {
    $parentTask = $this.GetCurrentParentTask()
    if ($parentTask -and $parentTask.ProjectFolderPath) {
        $actionLogPath = Join-Path $parentTask.ProjectFolderPath "$($parentTask.ActionLogName).txt"
        
        # Create action log if it doesn't exist
        if (-not (Test-Path $actionLogPath)) {
            try {
                $initialContent = "# Action Log for $($parentTask.Title)`n# Created: $(Get-Date)`n`n"
                [System.IO.File]::WriteAllText($actionLogPath, $initialContent)
            } catch {
                Write-Warning "Could not create action log file: $_"
                return $true
            }
        }
        
        return $this.EditExternalFile($actionLogPath, "ACTION LOG", $false)
    } else {
        Write-Warning "No project folder configured"
    }
    return $true
}

[SimpleTask] GetCurrentParentTask() {
    if ($this.FlatList.Count -eq 0) { return $null }
    $item = $this.FlatList[$this.SelectedIndex]
    return if ($item.Task.IsParent()) { $item.Task } else { $this.TaskService.GetTask($item.Task.ParentId) }
}
```

#### 2.3 External File Editor Integration
**Add to TaskListScreen class**:

```powershell
[bool] EditExternalFile([string]$filePath, [string]$title, [bool]$readOnly) {
    # Similar to EditNotes but for external files
    # Use same FullNotesEditor but with different save logic
    # For read-only: disable save operations, add "Edit in Notepad" option
    
    $editor = [FullNotesEditor]::new()
    $editor.SetBounds(0, 2, $this.Width, $this.Height - 3)
    
    try {
        $content = [System.IO.File]::ReadAllText($filePath)
        $editor.SetText($content)
    } catch {
        Write-Warning "Could not load file: $_"
        return $true
    }
    
    # Show editor with appropriate title and controls
    [Console]::Clear()
    [Console]::SetCursorPosition(0, 0)
    $titleColor = if ($readOnly) { $this.ErrorColor } else { $this.HeaderColor }
    Write-Host -NoNewline "$titleColor$title$($this.NormalColor)"
    
    if ($readOnly) {
        Write-Host -NoNewline " (Press 'E' to edit in Notepad)"
    }
    
    # Edit loop with read-only handling
    # Return to main screen when done
}
```

### Phase 3: Enhanced Data Safety System

#### 3.1 Versioned Backup System
**File**: `Core/BackupManager.ps1` (NEW FILE)
**Features**:
- Keep last 10 versions of each notes file
- Timestamp-based naming
- Automatic cleanup of old backups
- Integrity validation

```powershell
class BackupManager {
    static [string] CreateBackup([string]$originalFile, [int]$maxBackups = 10) {
        # Create timestamped backup
        # Clean up old backups
        # Return backup file path
    }
    
    static [bool] ValidateFileIntegrity([string]$filePath, [int]$expectedSize = -1) {
        # Basic file integrity checks
    }
    
    static [string[]] GetBackupFiles([string]$originalFile) {
        # Return list of backup files, newest first
    }
}
```

#### 3.2 Enhanced FullNotesEditor Safety
**Update**: `Core/FullNotesEditor.ps1`
- Integrate BackupManager
- Better crash recovery
- File lock detection (optional)
- More robust atomic saves

### Phase 4: UI Column Restructure

#### 4.1 Update Task Display Rendering
**File**: `Screens/TaskListScreen.ps1`
**New column layout**:
- Remove: Status (St), Priority columns
- Add: ID1 (3 chars), ID2 (12 chars), CreatedDate (8 chars)
- Keep: DueDate, Arrow, Title
- Order: `ID1 | ID2 | Created | Due | Arrow | Title`

**Update methods**:
- `RenderTaskItem()` - main rendering logic
- `GetItemDisplayLength()` - calculate widths
- Column constants need updating

#### 4.2 Enhanced Filter System
**File**: `Screens/TaskListScreen.ps1`
**New filter syntax**:
- `#tagname` - tag search
- `/clear` - clear filters (requires slash)
- `text` - search in titles
- Multiple filters: `#work urgent` (has work tag AND title contains urgent)

**Update methods**:
- `HandleFilterInput()` - parse new syntax
- `StartFilterInput()` - update UI prompts
- `ApplyFilter()` - implement new logic

### Phase 5: Testing & Polish

#### 5.1 Test Scenarios
1. **Settings Dialog**: All file browsers work, validation works
2. **Hotkeys**: All Ctrl+ combinations work correctly
3. **File Safety**: External file editing doesn't corrupt data
4. **Read-Only Mode**: Can view but not accidentally edit critical files
5. **Action Log**: Auto-creates, persists between sessions
6. **Backup System**: Creates backups, cleans up old ones

#### 5.2 Error Handling
- File not found errors
- Permission errors
- Disk full errors
- Invalid path handling

## Key Files to Modify/Create

### New Files:
- `Core/FileBrowser.ps1` - Windows file dialogs
- `Dialogs/ProjectSettingsDialog.ps1` - Per-project settings
- `Core/BackupManager.ps1` - Enhanced backup system

### Existing Files to Modify:
- `Models/SimpleTask.ps1` - Add project fields
- `Services/SimpleTaskService.ps1` - Save new fields
- `Screens/TaskListScreen.ps1` - Add hotkeys, file operations, column restructure
- `Core/FullNotesEditor.ps1` - Enhanced safety, external file support

## Implementation Notes

### Critical Safety Requirements:
1. **Never lose data** - Multiple backup strategies
2. **Atomic operations** - All file writes are atomic
3. **Graceful failures** - Show warnings, don't crash
4. **Read-only safety** - Prevent accidental edits of critical files

### User Experience Goals:
1. **Familiar interfaces** - Use native Windows dialogs
2. **Clear feedback** - Show what's happening
3. **Consistent hotkeys** - Ctrl+ pattern
4. **No learning curve** - Intuitive file operations

### Performance Considerations:
1. **Lazy loading** - Don't load files until needed
2. **Efficient rendering** - Only update changed areas
3. **Background operations** - Don't block UI for file operations

## Migration Strategy

### Existing Data:
- No breaking changes to existing task structure
- New fields are optional, default to empty strings
- Existing notes files continue to work unchanged
- Gradual adoption of new features per project

### Rollback Plan:
- New fields can be ignored by older versions
- Core functionality remains unchanged
- File backups allow recovery from issues

This plan provides comprehensive project management capabilities while maintaining the existing task management core and ensuring data safety throughout.
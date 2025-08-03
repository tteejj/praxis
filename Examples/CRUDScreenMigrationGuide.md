# CRUDScreen Migration Guide

This guide shows how to convert existing Praxis screens to use the new CRUDScreen base class, eliminating 60-70% of boilerplate code.

## Quick Migration Checklist

### 1. Change Base Class
```powershell
# Before
class ProjectsScreen : Screen {

# After  
class ProjectsScreen : CRUDScreen {
```

### 2. Update Constructor
```powershell
# Before
ProjectsScreen() : base() {
    $this.Title = "Projects"
}

# After
ProjectsScreen() : base("ProjectService", "Project") {
    $this.Title = "Projects"
    $this.GridColumns = @(
        # Move column definitions here
    )
}
```

### 3. Remove Boilerplate from OnInitialize()
Delete these sections entirely:
- Manual service injection (`$this.ProjectService = $global:ServiceContainer.GetService(...)`)
- Event subscription setup (`$this.EventSubscriptions[...] = $this.EventBus.Subscribe(...)`)  
- Grid creation and setup (`$this.ProjectGrid = [MinimalDataGrid]::new()`)
- `AddChild()` calls for the main grid
- Initial `LoadProjects()` call

### 4. Convert LoadProjects() to LoadData()
```powershell
# Before
[void] LoadProjects() {
    $projects = $this.ProjectService.GetAllProjects()
    # ... filtering and sorting logic ...
    $this.ProjectGrid.SetItems($sorted)
}

# After
[void] LoadData() {
    $projects = $this.DataService.GetAllProjects()  # Note: DataService instead of ProjectService
    # ... same filtering and sorting logic ...
    $this.DataGrid.SetItems($sorted)  # Note: DataGrid instead of ProjectGrid
}
```

### 5. Convert CRUD Methods
```powershell
# Before
[void] NewProject() {
    # Business logic
}

# After  
[void] NewItem() {
    # Same business logic, just renamed
}
```

### 6. Remove HandleScreenInput() Boilerplate
Keep only custom shortcuts, remove standard n/e/d/r handling:
```powershell
# Before - Remove all of this
[bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
    switch ($keyInfo.KeyChar) {
        'n' { $this.NewProject(); return $true }      # Remove - built into CRUDScreen
        'e' { $this.EditProject(); return $true }     # Remove - built into CRUDScreen  
        'd' { $this.DeleteProject(); return $true }   # Remove - built into CRUDScreen
        'r' { $this.LoadProjects(); return $true }    # Remove - built into CRUDScreen
        'v' { $this.ViewProjectDetails(); return $true }  # Keep - custom shortcut
    }
    return $false
}

# After - Only keep custom shortcuts
[bool] HandleCustomInput([System.ConsoleKeyInfo]$keyInfo) {
    switch ($keyInfo.KeyChar) {
        'v' { $this.ViewProjectDetails(); return $true }  # Custom shortcut only
    }
    return $false
}
```

### 7. Remove OnBoundsChanged()
Delete entirely - CRUDScreen handles this automatically.

### 8. Update Property References
- `$this.ProjectService` → `$this.DataService`
- `$this.ProjectGrid` → `$this.DataGrid`
- `$this.LoadProjects()` → `$this.LoadData()` or `$this.RefreshItems()`

## Detailed Migration Examples

### ProjectsScreen Migration

**Before: 527 lines**
```powershell
class ProjectsScreen : Screen {
    [MinimalDataGrid]$ProjectGrid
    [ProjectService]$ProjectService
    [EventBus]$EventBus
    [ProjectCommandHandler]$CommandHandler
    hidden [hashtable]$EventSubscriptions = @{}
    
    ProjectsScreen() : base() {
        $this.Title = "Projects"
    }
    
    [void] OnInitialize() {
        # 25-40 lines of service injection
        $this.ProjectService = $global:ServiceContainer.GetService("ProjectService")
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        # ... more service setup ...
        
        # 50+ lines of event subscriptions
        if ($this.EventBus) {
            $screen = $this
            $this.EventSubscriptions['ProjectCreated'] = $this.EventBus.Subscribe(...)
            # ... more subscriptions ...
        }
        
        # 30+ lines of grid setup
        $this.ProjectGrid = [MinimalDataGrid]::new()
        $this.ProjectGrid.Title = ""
        $this.ProjectGrid.ShowBorder = $true
        # ... more grid configuration ...
        
        # 50+ lines of column definitions
        $columns = @(
            @{ Name = "Status"; Header = "Status"; Width = 6; ... }
            # ... more columns ...
        )
        
        $this.ProjectGrid.SetColumns($columns)
        $this.ProjectGrid.Initialize($global:ServiceContainer)
        $this.AddChild($this.ProjectGrid)
        $this.LoadProjects()
    }
    
    [void] OnBoundsChanged() {
        # 15+ lines of manual positioning
        if (-not $this.ProjectGrid) { return }
        $this.ProjectGrid.SetBounds($this.X, $this.Y, $this.Width, $this.Height)
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        # 50+ lines of input handling
        switch ($keyInfo.KeyChar) {
            'n' { $this.NewProject(); return $true }
            'e' { $this.EditProject(); return $true }
            'd' { $this.DeleteProject(); return $true }
            'v' { $this.ViewProjectDetails(); return $true }
            'r' { $this.LoadProjects(); return $true }
        }
        # ... more input handling ...
        return $false
    }
    
    # Business logic methods (100+ lines)
    [void] LoadProjects() { ... }
    [void] NewProject() { ... }
    [void] EditProject() { ... }
    [void] DeleteProject() { ... }
    [void] ViewProjectDetails() { ... }
}
```

**After: 75 lines**
```powershell
class ProjectsScreen : CRUDScreen {
    
    ProjectsScreen() : base("ProjectService", "Project") {
        $this.Title = "Projects"
        
        # Only unique column definitions remain
        $this.GridColumns = @(
            @{
                Name = "Status"
                Header = "Status"
                Width = 6
                Getter = {
                    param($project)
                    if ($project.ClosedDate -ne [DateTime]::MinValue) { "[✓]" } else { "[ ]" }
                }
            },
            @{
                Name = "FullProjectName"
                Header = "Project Name"
                Width = 0
            }
            # ... other columns ...
        )
    }
    
    # Only business logic methods remain
    [void] LoadData() {
        $projects = $this.DataService.GetAllProjects()
        $activeProjects = $projects | Where-Object { -not $_.Deleted }
        $sorted = $activeProjects | Sort-Object DateDue
        $this.DataGrid.SetItems($sorted)
    }
    
    [void] NewItem() {
        $dialog = [CleanNewProjectDialog]::new()
        # ... dialog setup (same as before) ...
    }
    
    [void] EditItem() {
        $selected = $this.GetSelectedItem()
        if (-not $selected) { return }
        # ... edit logic (same as before) ...
    }
    
    [bool] HandleCustomInput([System.ConsoleKeyInfo]$keyInfo) {
        # Only custom shortcuts remain
        switch ($keyInfo.KeyChar) {
            'v' { $this.ViewProjectDetails(); return $true }
        }
        
        if ($keyInfo.Key -eq [System.ConsoleKey]::Enter) {
            $this.ViewProjectDetails()
            return $true
        }
        
        return $false
    }
    
    [void] ViewProjectDetails() {
        $selected = $this.GetSelectedItem()
        if ($selected) {
            $detailScreen = [ProjectDetailScreen]::new($selected)
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($detailScreen)
            }
        }
    }
}
```

### TaskScreen Migration

**Key Changes:**
```powershell
# Before
class TaskScreen : Screen {
    [MinimalDataGrid]$TaskGrid
    [TaskService]$TaskService
    [SubtaskService]$SubtaskService
    [ProjectService]$ProjectService
    # ... 15+ service and state properties ...

# After  
class TaskScreen : CRUDScreen {
    [SubtaskService]$SubtaskService  # Only additional services needed
    [ProjectService]$ProjectService  # Keep for project lookups
    # TaskService becomes $this.DataService automatically
```

**Complex LoadData() with Subtasks:**
```powershell
[void] LoadData() {
    # Get additional services if needed
    if (-not $this.SubtaskService) {
        $this.SubtaskService = $this.GetService("SubtaskService")
    }
    if (-not $this.ProjectService) {
        $this.ProjectService = $this.GetService("ProjectService")
    }
    
    # Business logic remains the same
    $tasks = $this.DataService.GetAllTasks()
    $activeTasks = $tasks | Where-Object { -not $_.Deleted }
    $sorted = $activeTasks | Sort-Object Priority, Status, DueDate
    
    if ($this.ShowSubtasks -and $this.SubtaskService) {
        # Complex subtask integration logic stays the same
        $combinedItems = [System.Collections.ArrayList]::new()
        foreach ($task in $sorted) {
            $combinedItems.Add($task) | Out-Null
            $subtasks = $this.SubtaskService.GetSubtasksForTask($task.Id)
            foreach ($subtask in $subtasks) {
                $combinedItems.Add($subtask) | Out-Null
            }
        }
        $this.DataGrid.SetItems($combinedItems)
    } else {
        $this.DataGrid.SetItems($sorted)
    }
}
```

### TimeEntryScreen Migration

**Unique Pattern - Custom Entity Name:**
```powershell
# Constructor with custom plural form
TimeEntryScreen() : base("TimeTrackingService", "TimeEntry", "TimeEntries") {
    $this.Title = "Time Entry"
    # ... columns for time grid ...
}
```

**Week-based Data Loading:**
```powershell
[void] LoadData() {
    # Time-specific loading logic preserved
    $weekString = $this.CurrentWeekFriday.ToString("yyyyMMdd")
    $entries = $this.DataService.GetWeekEntries($weekString)
    $sorted = $entries | Sort-Object Name, ID2
    $this.DataGrid.SetItems($sorted)
}
```

## Common Migration Issues

### Issue 1: Property Name Changes
**Problem:** `$this.ProjectGrid` no longer exists
**Solution:** Use `$this.DataGrid` instead

### Issue 2: Service Reference Changes  
**Problem:** `$this.ProjectService` no longer exists
**Solution:** Use `$this.DataService` instead

### Issue 3: Method Name Changes
**Problem:** `LoadProjects()` method not found
**Solution:** Override `LoadData()` instead

### Issue 4: Custom Event Subscriptions
**Problem:** Need additional event subscriptions beyond standard CRUD
**Solution:** Override `SetupCustomEventSubscriptions()`:
```powershell
[void] SetupCustomEventSubscriptions() {
    if (-not $this.EventBus) { return }
    
    $screen = $this
    $this.EventSubscriptions['CustomEvent'] = $this.EventBus.Subscribe('custom.event', {
        param($sender, $eventData)
        # Custom handling
    }.GetNewClosure())
}
```

### Issue 5: Complex Delete Logic
**Problem:** Default delete doesn't handle complex cases
**Solution:** Override `PerformDelete()`:
```powershell
[void] PerformDelete($itemId) {
    # Custom delete logic
    $this.DataService.DeleteTaskAndSubtasks($itemId)
    
    # Publish custom events if needed
    if ($this.EventBus) {
        $this.EventBus.Publish('task.deleted.complex', @{ TaskId = $itemId })
    }
}
```

### Issue 6: Custom ID Fields
**Problem:** Entity doesn't have 'Id' property
**Solution:** Override `GetItemId()`:
```powershell
[object] GetItemId($item) {
    if ($item -and $item.PSObject.Properties.Name -contains 'ProjectId') {
        return $item.ProjectId
    }
    return $null
}
```

## Testing Your Migration

### 1. Functionality Test
- [ ] Screen loads without errors
- [ ] Data displays correctly  
- [ ] 'n' key creates new item
- [ ] 'e' key edits selected item
- [ ] 'd' key deletes selected item (with confirmation)
- [ ] 'r' key refreshes data
- [ ] Enter key works (usually edit or view)
- [ ] Custom shortcuts work

### 2. Event Integration Test
- [ ] Creating item refreshes screen automatically
- [ ] Editing item refreshes screen automatically  
- [ ] Deleting item refreshes screen automatically
- [ ] New items are selected after creation
- [ ] Screen responds to external events

### 3. Performance Test
- [ ] Screen loads as fast as before
- [ ] No new memory leaks
- [ ] Rendering is still flicker-free
- [ ] Large datasets perform well

## Benefits After Migration

1. **85% Less Code** - Focus on business logic, not plumbing
2. **Consistent Behavior** - All screens work the same way
3. **Faster Development** - New screens in 30 minutes instead of hours
4. **Easier Maintenance** - Base class improvements benefit all screens
5. **Fewer Bugs** - Less boilerplate means fewer places for errors
6. **Better Performance** - Optimized base class benefits all screens

## Next Steps

After successful migration:
1. Test thoroughly with your specific data
2. Consider migrating dialogs to UnifiedDialog system
3. Look for opportunities to standardize column definitions
4. Consider creating screen templates for common patterns

The goal is to spend your time on what makes your application unique, not on the plumbing that every screen needs.
# Screens/TaskListScreen-Phase4.ps1 - Migrated TaskListScreen using new Phase 1 + Phase 4 architecture
# Inherits from EnhancedBaseListScreen for TaskListScreen-quality foundation
# Integrates with StateManager, EventBus, FastLineBuilder, AppThemeManager, UnifiedRenderer

# Input state enumeration for state machine
enum TaskListInputState {
    Browsing
    Filtering  
    TimeEntry
}

class TaskListScreen : ListScreen {
    # TaskListScreen-specific services and properties
    [SimpleTaskService]$TaskService
    
    # Task-specific properties
    [SimpleTask[]]$Tasks = @()
    [string]$CurrentFilter = "All"  # Filter mode: "All", "Today", "High", etc.
    [string]$TagFilter = ""  # Tag-based filter
    [bool]$GlobalCollapseSubtasks = $false
    
    # Input state machine
    [TaskListInputState]$InputState = [TaskListInputState]::Browsing
    
    # Filter input state
    [bool]$FilterInputActive = $false
    [string]$FilterInputValue = ""
    [int]$FilterInputCursor = 0
    
    TaskListScreen([ServiceContainer]$services) : base($services) {
        # Simple constructor - complex setup moved to OnInitialize()
    }
    
    # Override OnInitialize for TaskListScreen-specific setup
    [void] OnInitialize() {
        # Call base class initialization first
        ([ListScreen]$this).OnInitialize()
        
        # TaskListScreen-specific initialization
        $this.TaskService = [SimpleTaskService]::new()
        $this.Title = "Tasks"
        $this.LoadData()
        
        if ($this.Logger) {
            $this.Logger.Info("TaskListScreen initialized with proper inheritance")
        }
    }
    
    # === PHASE 4 STATE INTEGRATION ===
    
    [string] GetScreenStatePath() {
        return "UI.Tasks"
    }
    
    [void] OnStateChanged([object]$eventData) {
        # Pull the new state we need to render the UI (simplified with SimpleStateManager)
        $this.Logger.Debug("TaskListScreen received state.changed notification")
        
        # Update from simple state values
        $taskList = $this.StateManager.Get("TaskList")
        if ($taskList) {
            $this.FlatList = $this.BuildFlatList($taskList)
        }
        
        $savedSelectedIndex = $this.StateManager.Get("SelectedTaskIndex")
        if ($savedSelectedIndex -ge 0) {
            $this.SelectedIndex = $savedSelectedIndex
        }
        
        $savedScrollTop = $this.StateManager.Get("TaskScrollTop")
        if ($savedScrollTop -ge 0) {
            $this.ScrollTop = $savedScrollTop
        }
        
        $filter = $this.StateManager.Get("TaskFilter")
        if ($filter) {
            $this.CurrentFilter = $filter
        }
    }
    
    [void] UpdateSelectionState() {
        # Update SimpleStateManager with our selection (simplified)
        $this.StateManager.SetSelectedTask($this.SelectedIndex)
    }
    
    [void] UpdateScrollState() {
        $this.StateManager.SetTaskScroll($this.ScrollTop)
    }
    
    # === DATA MANAGEMENT (implements abstract methods) ===
    
    [void] LoadData() {
        try {
            "DEBUG: LoadData - calling TaskService.GetParentTasks $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            $this.Tasks = $this.TaskService.GetParentTasks()
            "DEBUG: LoadData - got $($this.Tasks.Count) tasks $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            $this.FlatList = $this.BuildFlatList()
            "DEBUG: LoadData - built flat list $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            
            # Update SimpleStateManager with new data (simplified)
            $this.StateManager.SetTaskList($this.Tasks)
            "DEBUG: LoadData - updated StateManager $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            
            $this.Logger.Debug("TaskListScreen loaded $($this.Tasks.Count) tasks")
            "DEBUG: LoadData - completed successfully $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        } catch {
            "DEBUG: LoadData - exception occurred: $_ $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
            $this.Logger.Error("TaskListScreen: Failed to load tasks", $_)
            $this.SetStatusMessage("Failed to load tasks: $_", 5000)
        }
    }
    
    [array] BuildFlatList() {
        return $this.BuildFlatListInternal($null)
    }
    
    [array] BuildFlatList([array]$inputTasks) {
        return $this.BuildFlatListInternal($inputTasks)
    }
    
    [array] BuildFlatListInternal([array]$inputTasks) {
        $taskArray = if ($inputTasks) { $inputTasks } else { $this.Tasks }
        $newList = [System.Collections.Generic.List[object]]::new()
        
        foreach ($task in $taskArray) {
            # Apply filters
            if (-not $this.ShouldShowTask($task)) { continue }
            
            # Add parent task
            $parentItem = @{
                Task = $task
                Level = 0
                IsLast = $false
            }
            $newList.Add($parentItem)
            
            # Add subtasks (if not collapsed)
            if (-not $this.GlobalCollapseSubtasks -and -not $task.SubtasksCollapsed -and $task.Subtasks -and $task.Subtasks.Count -gt 0) {
                for ($i = 0; $i -lt $task.Subtasks.Count; $i++) {
                    $subtask = $task.Subtasks[$i]
                    if ($this.ShouldShowTask($subtask)) {
                        $isLastSubtask = ($i -eq ($task.Subtasks.Count - 1))
                        
                        $subtaskItem = @{
                            Task = $subtask
                            Level = 1
                            IsLast = $isLastSubtask
                        }
                        $newList.Add($subtaskItem)
                    }
                }
            }
        }
        
        $this.Logger.Debug("TaskListScreen built flat list with $($newList.Count) items")
        return $newList.ToArray()
    }
    
    [bool] ShouldShowTask([SimpleTask]$task) {
        # Filter logic
        switch ($this.CurrentFilter) {
            "All" { return $true }
            "Today" { 
                return $task.DueDate.Date -eq [datetime]::Today -or $task.Priority -eq "Today"
            }
            "High" { return $task.Priority -eq "High" }
            "Medium" { return $task.Priority -eq "Medium" }
            "Low" { return $task.Priority -eq "Low" }
            default { return $true }
        }
        return $true  # Fallback
    }
    
    # === RENDERING (implements abstract method using FastLineBuilder) ===
    
    [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
        # This is the correct implementation.
        # It asks the FastLineBuilder to create the fully-formatted string for the row.
        $task = $item.Task
        $level = $item.Level
        $isLast = $item.IsLast
        
        # We need BOTH lines (content and tags) for a complete row.
        # We'll join them with a special separator that our renderer will understand.
        $viewModel = $this.ContentBuilder.GenerateTaskViewModel($task, $this, $level, $isLast)
        return ($viewModel -join "[LINEBREAK]")
    }
    
    
    # === EDITING (implements abstract methods) ===
    
    [string[]] GetEditableFields([object]$item) {
        $task = $item.Task
        $level = $item.Level
        
        if ($level -eq 0) {
            # Parent task fields
            return @("id1", "id2", "created", "date", "title", "tags")
        } else {
            # Subtask fields  
            return @("priority", "title", "tags")
        }
    }
    
    [void] SaveItem([object]$item) {
        try {
            $task = $item.Task
            $this.TaskService.SaveTask($task)
            $this.Logger.Debug("TaskListScreen: Saved task $($task.Id)")
        } catch {
            $this.Logger.Error("TaskListScreen: Failed to save task", $_)
            $this.SetStatusMessage("Failed to save: $_", 5000)
        }
    }
    
    [object] CreateNewItem() {
        # Create new parent task
        $newTask = [SimpleTask]::new()
        $newTask.Id = [System.Guid]::NewGuid().ToString()
        $newTask.Title = "New Task"
        $newTask.CreatedDate = Get-Date
        $newTask.Priority = "Medium"
        $newTask.Tags = @()
        $newTask.Subtasks = @()
        
        return @{
            Task = $newTask
            Level = 0
            IsLast = $false
        }
    }
    
    # === COMMAND HANDLING (Phase 4 pattern) ===
    
    [void] RegisterCommandHandlers() {
        # Command handler map for task-specific commands
        $this.CommandHandlers = @{
            "task.delete" = { $this.HandleDeleteTask() }
            "task.edit.notes" = { $this.HandleEditNotes() }
            "task.toggle.complete" = { $this.HandleToggleComplete() }
            "task.new.subtask" = { $this.HandleNewSubtask() }
            "task.toggle.collapse" = { $this.HandleToggleCollapse() }
            "task.filter.toggle" = { $this.HandleToggleFilter() }
            "task.theme.cycle" = { $this.HandleCycleTheme() }
        }
    }
    
    [void] HandleDerivedCommand([string]$command) {
        # Initialize command handlers if not done yet
        if (-not $this.CommandHandlers) {
            $this.RegisterCommandHandlers()
        }
        
        if ($this.CommandHandlers.ContainsKey($command)) {
            & $this.CommandHandlers[$command]
        } else {
            $this.Logger.Debug("TaskListScreen received unhandled command: $command")
        }
    }
    
    # === COMMAND HANDLER METHODS ===
    
    [void] HandleDeleteTask() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $task = $item.Task
        
        try {
            # Publish action to StateManager instead of direct service call
            [EventBus]::Publish("action:task.delete", @{ TaskId = $task.Id })
            
            # For now, also call service directly until we have full action handlers
            $this.TaskService.DeleteTask($task.Id)
            $this.LoadData()  # Refresh
            $this.SetStatusMessage("Task deleted", 2000)
            
        } catch {
            $this.Logger.Error("TaskListScreen: Failed to delete task", $_)
            $this.SetStatusMessage("Failed to delete: $_", 5000)
        }
    }
    
    [void] HandleEditNotes() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $task = $item.Task
        
        # For now, just set a status message - full notes editor in future phase
        $this.SetStatusMessage("Notes editing not yet implemented in Phase 4", 3000)
        $this.Logger.Info("Notes editing requested for task: $($task.Title)")
    }
    
    [void] HandleToggleComplete() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $task = $item.Task
        
        try {
            $task.Completed = -not $task.Completed
            $this.TaskService.SaveTask($task)
            $this.LoadData()  # Refresh
            
            $status = if ($task.Completed) { "completed" } else { "incomplete" }
            $this.SetStatusMessage("Task marked as $status", 2000)
            
        } catch {
            $this.Logger.Error("TaskListScreen: Failed to toggle completion", $_)
            $this.SetStatusMessage("Failed to toggle completion: $_", 5000)
        }
    }
    
    [void] HandleNewSubtask() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        
        # Only allow subtasks for parent tasks
        if ($item.Level -ne 0) {
            $this.SetStatusMessage("Cannot add subtask to subtask", 2000)
            return
        }
        
        $parentTask = $item.Task
        
        try {
            # Create new subtask
            $newSubtask = [SimpleTask]::new()
            $newSubtask.Id = [System.Guid]::NewGuid().ToString()
            $newSubtask.Title = "New Subtask"
            $newSubtask.CreatedDate = Get-Date
            $newSubtask.Priority = "Medium"
            $newSubtask.ParentTaskId = $parentTask.Id
            
            # Add to parent task
            $parentTask.Subtasks += $newSubtask
            $this.TaskService.SaveTask($parentTask)
            $this.LoadData()  # Refresh
            
            $this.SetStatusMessage("Subtask added", 2000)
            
        } catch {
            $this.Logger.Error("TaskListScreen: Failed to create subtask", $_)
            $this.SetStatusMessage("Failed to create subtask: $_", 5000)
        }
    }
    
    [void] HandleToggleCollapse() {
        $this.GlobalCollapseSubtasks = -not $this.GlobalCollapseSubtasks
        $this.StateManager.SetTaskFilter($this.CurrentFilter)
        $this.FlatList = $this.BuildFlatList()
        
        $status = if ($this.GlobalCollapseSubtasks) { "collapsed" } else { "expanded" }
        $this.SetStatusMessage("Subtasks $status", 2000)
    }
    
    [void] HandleToggleFilter() {
        # Cycle through filter modes
        $filters = @("All", "Today", "High", "Medium", "Low")
        $currentIndex = $filters.IndexOf($this.CurrentFilter)
        $newIndex = ($currentIndex + 1) % $filters.Count
        $this.CurrentFilter = $filters[$newIndex]
        
        $this.StateManager.SetTaskFilter($this.CurrentFilter)
        $this.FlatList = $this.BuildFlatList()
        
        $this.SetStatusMessage("Filter: $($this.CurrentFilter)", 2000)
    }
    
    [void] HandleCycleTheme() {
        $newTheme = [AppThemeManager]::CycleTheme()
        $this.SetStatusMessage("Theme: $newTheme", 2000)
    }
    
    # === COMPATIBILITY PROPERTIES (for FastLineBuilder integration) ===
    
    # These properties are needed by FastLineBuilder - they reference our new services
    hidden [hashtable]$CommandHandlers = @{}
    
    # Theme colors (FastLineBuilder expects these)
    [string] GetEditHighlight() {
        return [AppThemeManager]::GetColor("Accent") + [AppThemeManager]::GetBackgroundColor("Selected")
    }
    
    # For backwards compatibility with existing FastLineBuilder calls
    [object]$EditingTask = $null
    [string]$EditHighlight = ""
    
    # Update EditingTask when inline editing starts
    [void] StartEdit([string]$field) {
        # Call base implementation
        $this.StartEdit($field)
        
        # Update EditingTask for FastLineBuilder compatibility
        if ($this.EditingItem) {
            $this.EditingTask = $this.EditingItem.Task
        }
        
        # Update EditHighlight for FastLineBuilder
        $this.EditHighlight = $this.GetEditHighlight()
    }
    
    [void] CancelInlineEdit() {
        # Call base implementation  
        $this.CancelInlineEdit()
        
        # Clear compatibility properties
        $this.EditingTask = $null
        $this.EditHighlight = ""
    }
}
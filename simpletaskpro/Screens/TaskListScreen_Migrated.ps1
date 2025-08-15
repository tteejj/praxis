# TaskListScreen.ps1 - Migrated to Smart Component Architecture
# Clean, simple implementation that inherits powerful engine from ListScreen
# Follows plan_final.md specifications - only overrides essential hooks

class TaskListScreen : ListScreen {
    # Task-specific services and properties
    [SimpleTaskService]$TaskService
    
    # Task-specific properties only
    [SimpleTask[]]$Tasks = @()
    [string]$CurrentFilter = "All"  # Filter mode: "All", "Today", "High", etc.
    [string]$TagFilter = ""  # Tag-based filter

    TaskListScreen([ServiceContainer]$services) : base($services) {
        # Simple constructor - setup moved to OnInitialize()
    }
    
    # Override OnInitialize for TaskListScreen-specific setup
    [void] OnInitialize() {
        # Call base class initialization first
        ([ListScreen]$this).OnInitialize()
        
        # Get TaskListScreen-specific services
        $this.TaskService = $this.Services.GetService("SimpleTaskService")
        $this.Title = "Tasks"
        
        # Load initial data now that services are available
        $this.LoadData()
        
        if ($this.Logger) {
            $this.Logger.Info("TaskListScreen initialized successfully")
        }
    }
    
    # === REQUIRED OVERRIDE METHODS (from plan_final.md) ===
    
    [void] LoadData() {
        try {
            if ($this.TaskService -eq $null) {
                $this.Logger.Error("TaskListScreen: TaskService is null in LoadData")
                $this.Tasks = @()
                $this.FlatList = [System.Collections.Generic.List[object]]::new()
                return
            }
            
            $this.Tasks = $this.TaskService.GetParentTasks()
            $this.FlatList = $this.BuildFlatList()
            
            if ($this.Logger) {
                $this.Logger.Debug("TaskListScreen loaded $($this.Tasks.Count) tasks")
            }
        } catch {
            $this.Logger.Error("TaskListScreen: Failed to load tasks", $_)
            $this.SetStatusMessage("Failed to load tasks: $_", 5000)
        }
    }
    
    [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
        # Delegate to FastLineBuilder for formatting
        $task = $item.Task
        $level = $item.Level
        $isLast = $item.IsLast
        
        $viewModel = $this.ContentBuilder.GenerateTaskViewModel($task, $this, $level, $isLast)
        return ($viewModel -join "[LINEBREAK]")
    }
    
    [void] HandleDerivedCommand([string]$command) {
        # Handle task-specific commands
        switch ($command) {
            "action.new" { $this.CreateNewTask() }
            "action.edit" { $this.EditCurrentTask() }
            "action.delete" { $this.DeleteCurrentTask() }
            "task.toggle.complete" { $this.ToggleCurrentTaskComplete() }
            "task.filter.toggle" { $this.ToggleFilter() }
            default { 
                $this.Logger.Debug("TaskListScreen: Unhandled command: $command") 
            }
        }
    }
    
    # === TASK-SPECIFIC HELPER METHODS ===
    
    [array] BuildFlatList() {
        $newList = [System.Collections.Generic.List[object]]::new()
        
        foreach ($task in $this.Tasks) {
            # Apply filters
            if (-not $this.ShouldShowTask($task)) { continue }
            
            # Add parent task
            $parentItem = @{
                Task = $task
                Level = 0
                IsLast = $false
            }
            $newList.Add($parentItem)
            
            # Add subtasks if not collapsed
            if (-not $task.SubtasksCollapsed -and $task.Subtasks -and $task.Subtasks.Count -gt 0) {
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
        
        return $newList.ToArray()
    }
    
    [bool] ShouldShowTask([SimpleTask]$task) {
        # Simple filter logic
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
    }
    
    # === TASK-SPECIFIC COMMAND IMPLEMENTATIONS ===
    
    [void] CreateNewTask() {
        try {
            $newTask = [SimpleTask]::new()
            $newTask.Title = "New Task"
            $newTask.CreatedDate = Get-Date
            $newTask.Priority = "Medium"
            
            $this.TaskService.AddTask($newTask)
            $this.LoadData()  # Refresh
            $this.SetStatusMessage("New task created", 2000)
        } catch {
            $this.Logger.Error("Failed to create new task", $_)
            $this.SetStatusMessage("Failed to create task: $_", 5000)
        }
    }
    
    [void] EditCurrentTask() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $task = $item.Task
        
        # For now, just show status - full edit in future
        $this.SetStatusMessage("Edit: $($task.Title)", 3000)
    }
    
    [void] DeleteCurrentTask() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $task = $item.Task
        
        try {
            $this.TaskService.DeleteTask($task.Id)
            $this.LoadData()  # Refresh
            $this.SetStatusMessage("Task deleted", 2000)
        } catch {
            $this.Logger.Error("Failed to delete task", $_)
            $this.SetStatusMessage("Failed to delete: $_", 5000)
        }
    }
    
    [void] ToggleCurrentTaskComplete() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $task = $item.Task
        
        try {
            $this.TaskService.ToggleComplete($task.Id)
            $this.LoadData()  # Refresh
            
            $status = if ($task.Completed) { "completed" } else { "incomplete" }
            $this.SetStatusMessage("Task marked as $status", 2000)
        } catch {
            $this.Logger.Error("Failed to toggle completion", $_)
            $this.SetStatusMessage("Failed to toggle: $_", 5000)
        }
    }
    
    [void] ToggleFilter() {
        # Cycle through filter modes
        $filters = @("All", "Today", "High", "Medium", "Low")
        $currentIndex = $filters.IndexOf($this.CurrentFilter)
        $newIndex = ($currentIndex + 1) % $filters.Count
        $this.CurrentFilter = $filters[$newIndex]
        
        $this.LoadData()  # Refresh with new filter
        $this.SetStatusMessage("Filter: $($this.CurrentFilter)", 2000)
    }
}
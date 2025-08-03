# TaskScreen.ps1 - Task management screen using CRUDScreen base class

class TaskScreen : CRUDScreen {
    [SubtaskService]$SubtaskService
    [ProjectService]$ProjectService
    hidden [bool]$ShowSubtasks = $true
    hidden [hashtable]$ProjectCache = @{}
    
    TaskScreen() : base("TaskService", "Task") {
        $this.Title = "Tasks"
    }
    
    # Override OnInitialize to inject additional services
    [void] OnInitialize() {
        # Call base initialization first (handles TaskService and EventBus)
        ([CRUDScreen]$this).OnInitialize()
        
        # Inject additional services needed by TaskScreen
        $this.SubtaskService = $this.GetService("SubtaskService")
        
        $this.ProjectService = $this.GetService("ProjectService")
    }
    
    # Override SetupDataGrid to use UnifiedList and custom columns
    [void] SetupDataGrid() {
        # Create UnifiedList in DataGrid mode
        $this.DataGrid = [UnifiedList]::new([UnifiedListMode]::DataGrid)
        $this.DataGrid.Title = ""  # Don't show title in grid since screen has title
        $this.DataGrid.ShowBorder = $false   # Remove borders per requirements
        $this.DataGrid.ShowHeader = $true
        $this.DataGrid.ShowColumnSeparators = $false
        
        # Define custom columns for tasks with subtask support
        $screen = $this
        $columns = @(
            @{
                Name = "Status"
                Header = "S"
                Width = 1
                Getter = {
                    param($item)
                    if ($item.PSObject.Properties.Name -contains 'ParentTaskId') {
                        # Subtask - no status shown in grid (shown in title instead)
                        return " "
                    }
                    switch ($item.Status) {
                        ([TaskStatus]::Pending) { return "P" }
                        ([TaskStatus]::InProgress) { return "W" }
                        ([TaskStatus]::Completed) { return "D" }
                        ([TaskStatus]::Cancelled) { return "X" }
                        default { return "?" }
                    }
                }
            },
            @{
                Name = "Priority"
                Header = "P"
                Width = 1
                Getter = {
                    param($item)
                    if ($item.PSObject.Properties.Name -contains 'ParentTaskId') {
                        # Subtask - no priority shown in grid
                        return " "
                    }
                    switch ($item.Priority) {
                        ([TaskPriority]::High) { return "H" }
                        ([TaskPriority]::Medium) { return "M" }
                        ([TaskPriority]::Low) { return "L" }
                        default { return " " }
                    }
                }
            },
            @{
                Name = "Title"
                Header = "Task"
                Width = 0  # Flexible width
                Getter = {
                    param($item)
                    if ($item.PSObject.Properties.Name -contains 'ParentTaskId') {
                        # Subtask - show indented with status
                        $status = switch ($item.Status) {
                            ([TaskStatus]::Pending) { "[ ]" }
                            ([TaskStatus]::InProgress) { "[~]" }
                            ([TaskStatus]::Completed) { "[✓]" }
                            ([TaskStatus]::Cancelled) { "[✗]" }
                            default { "[?]" }
                        }
                        return "  └ $status $($item.Title)"
                    } else {
                        # Main task - include subtask count if any
                        $title = $item.Title
                        if ($screen.SubtaskService) {
                            $stats = $screen.SubtaskService.GetTaskStatistics($item.Id)
                            if ($stats.Total -gt 0) {
                                $title += " [$($stats.Completed)/$($stats.Total)]"
                            }
                        }
                        return $title
                    }
                }
            },
            @{
                Name = "Project"
                Header = "Project"
                Width = 15
                Getter = {
                    param($item)
                    if ($item.PSObject.Properties.Name -contains 'ParentTaskId') {
                        # Subtask - no project shown
                        return ""
                    }
                    if ($item.ProjectId -and $screen.ProjectService) {
                        # Cache project lookups for performance
                        if (-not $screen.ProjectCache.ContainsKey($item.ProjectId)) {
                            $project = $screen.ProjectService.GetProject($item.ProjectId)
                            if ($project) {
                                $screen.ProjectCache[$item.ProjectId] = $project.FullProjectName
                            } else {
                                $screen.ProjectCache[$item.ProjectId] = ""
                            }
                        }
                        return $screen.ProjectCache[$item.ProjectId]
                    }
                    return ""
                }
            },
            @{
                Name = "DueDate"
                Header = "Due"
                Width = 10
                Getter = {
                    param($item)
                    if ($item.PSObject.Properties.Name -contains 'ParentTaskId') {
                        # Subtask - no due date in grid
                        return ""
                    }
                    if ($item.DueDate -ne [DateTime]::MinValue) {
                        return $item.DueDate.ToString("yyyy-MM-dd")
                    }
                    return ""
                }
            },
            @{
                Name = "Tags"
                Header = "Tags"
                Width = 15
                Getter = {
                    param($item)
                    if ($item.PSObject.Properties.Name -contains 'ParentTaskId') {
                        # Subtask - no tags shown
                        return ""
                    }
                    if ($item.Tags -and $item.Tags.Count -gt 0) {
                        return ($item.Tags -join ",")
                    }
                    return ""
                }
            }
        )
        
        $this.DataGrid.SetColumns($columns)
        $this.DataGrid.Initialize($global:ServiceContainer)
        $this.AddChild($this.DataGrid)
    }
    
    # Override LoadData to implement task-specific data loading
    [void] LoadData() {
        $tasks = $this.DataService.GetAllTasks()
        
        # Clear project cache for fresh lookups
        $this.ProjectCache.Clear()
        
        # Filter out deleted tasks
        $activeTasks = $tasks | Where-Object { -not $_.Deleted }
        
        # Sort by priority (high first), then status, then due date
        $sorted = $activeTasks | Sort-Object -Property `
            @{Expression = {$_.Priority}; Descending = $true},
            @{Expression = {$_.Status}; Ascending = $true},
            @{Expression = {if ($_.DueDate -eq [DateTime]::MinValue) { [DateTime]::MaxValue } else { $_.DueDate }}; Ascending = $true}
        
        if ($this.ShowSubtasks -and $this.SubtaskService) {
            # Create combined list with tasks and their subtasks
            $combinedItems = [System.Collections.ArrayList]::new()
            
            foreach ($task in $sorted) {
                $combinedItems.Add($task) | Out-Null
                
                # Add subtasks for this task
                $subtasks = $this.SubtaskService.GetSubtasksForTask($task.Id)
                foreach ($subtask in $subtasks) {
                    $combinedItems.Add($subtask) | Out-Null
                }
            }
            
            $this.DataGrid.SetItems($combinedItems)
        } else {
            $this.DataGrid.SetItems($sorted)
        }
        
        $this.DataGrid.Invalidate()
        $this.Invalidate()
    }
    
    # Override CRUD operations for task-specific behavior
    [void] NewItem() {
        $dialog = [NewTaskDialog]::new()
        $global:ScreenManager.Push($dialog)
    }
    
    [void] EditItem() {
        $selected = $this.GetSelectedItem()
        if (-not $selected) { return }
        
        # Check if it's a subtask or main task
        if ($selected.PSObject.Properties.Name -contains 'ParentTaskId') {
            # Edit subtask
            $this.EditSubtask($selected)
            return
        }
        
        # Create edit task dialog
        $dialog = [EditTaskDialog]::new($selected)
        $global:ScreenManager.Push($dialog)
    }
    
    # Override PerformDelete to handle subtasks
    [void] PerformDelete($itemId) {
        $selected = $this.GetSelectedItem()
        if (-not $selected) { return }
        
        # Check if it's a subtask or main task
        $isSubtask = $selected.PSObject.Properties.Name -contains 'ParentTaskId'
        
        if ($isSubtask) {
            # Delete subtask
            $this.SubtaskService.DeleteSubtask($itemId)
        } else {
            # Delete task (and all its subtasks)
            $this.DataService.DeleteTask($itemId)
        }
    }
    
    # Task-specific methods
    [void] CycleStatus() {
        $selected = $this.GetSelectedItem()
        if (-not $selected) { return }
        
        # Cycle through status values
        $newStatus = switch ($selected.Status) {
            ([TaskStatus]::Pending) { [TaskStatus]::InProgress }
            ([TaskStatus]::InProgress) { [TaskStatus]::Completed }
            ([TaskStatus]::Completed) { [TaskStatus]::Cancelled }
            ([TaskStatus]::Cancelled) { [TaskStatus]::Pending }
        }
        
        if ($selected.PSObject.Properties.Name -contains 'ParentTaskId') {
            # Update subtask
            $selected.Status = $newStatus
            $selected.UpdatedAt = [DateTime]::Now
            $this.SubtaskService.SaveSubtask($selected)
        } else {
            # Update task
            $this.DataService.UpdateTaskStatus($selected.Id, $newStatus)
        }
        
        $this.LoadData()
    }
    
    [void] AddSubtask() {
        $selected = $this.GetSelectedItem()
        if (-not $selected -or -not $this.SubtaskService) { return }
        
        # Find the parent task (if selected item is a subtask, get its parent)
        $parentTask = $null
        if ($selected.PSObject.Properties.Name -contains 'ParentTaskId') {
            # Selected item is a subtask, find its parent
            $parentTask = $this.DataService.GetTask($selected.ParentTaskId)
        } else {
            # Selected item is a task
            $parentTask = $selected
        }
        
        if (-not $parentTask) { return }
        
        # Create subtask dialog
        $dialog = [SubtaskDialog]::new($parentTask)
        $global:ScreenManager.Push($dialog)
    }
    
    [void] ToggleSubtaskView() {
        $this.ShowSubtasks = -not $this.ShowSubtasks
        $this.LoadData()
    }
    
    [void] EditSubtask([PSCustomObject]$subtask) {
        if (-not $subtask -or -not $this.SubtaskService) { return }
        
        # Get parent task for context
        $parentTask = $this.DataService.GetTask($subtask.ParentTaskId)
        if (-not $parentTask) { return }
        
        # Create subtask dialog for editing
        $dialog = [SubtaskDialog]::new($parentTask, $subtask)
        $global:ScreenManager.Push($dialog)
    }
    
    [void] CyclePriority() {
        $selected = $this.GetSelectedItem()
        if (-not $selected) { return }
        
        # Don't cycle priority for subtasks in this view
        if ($selected.PSObject.Properties.Name -contains 'ParentTaskId') { return }
        
        $this.DataService.CyclePriority($selected.Id)
        $this.LoadData()
    }
    
    # Override custom input handling for task-specific shortcuts
    [bool] HandleCustomInput([System.ConsoleKeyInfo]$keyInfo) {
        # Task-specific shortcuts
        switch ($keyInfo.KeyChar) {
            's' { $this.CycleStatus(); return $true }
            'p' { $this.CyclePriority(); return $true }
            't' { $this.ToggleSubtaskView(); return $true }
            'a' { $this.AddSubtask(); return $true }
        }
        
        return $false  # Not handled
    }
    
    # Compatibility methods for MainScreen integration
    [void] NewTask() { $this.NewItem() }
    [void] EditTask() { $this.EditItem() }
    [void] DeleteTask() { $this.DeleteItem() }
    [void] LoadTasks() { $this.LoadData() }
    [void] RefreshTasks() { $this.RefreshItems() }
}
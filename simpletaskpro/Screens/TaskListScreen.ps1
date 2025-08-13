# TaskListScreen.ps1 - Simple task list with subtasks
# Enhanced with FastLineBuilder and SmoothRenderer for better performance

# Input state enumeration for state machine
enum TaskListInputState {
    Browsing
    Filtering
    TimeEntry
}

class TaskListScreen : ListScreen {
    [FastLineBuilder]$ContentBuilder
    [SimpleTaskService]$TaskService
    
    [SimpleTask[]]$Tasks
    
    [int]$Width
    [int]$Height
    [bool]$GlobalCollapseSubtasks = $false
    [string]$CurrentFilter = "All"  # Filter mode: "All", "Today", "High", etc.
    [string]$TagFilter = ""  # Tag-based filter like "work", "personal", etc.
    
    
    
    
    
    
    
    # Column widths - project management layout
    [int]$COLUMN_ID1 = 5         # "Q4  " (3 chars + 2 spaces)
    [int]$COLUMN_ID2 = 14        # "RPT-2025-001  " (12 chars + 2 spaces)
    [int]$COLUMN_CREATED = 12    # "2025-08-06  " (10 chars + 2 spaces)
    [int]$COLUMN_DATE = 12       # "2025-08-06  " (10 chars + 2 spaces)
    [int]$COLUMN_ARROW = 3       # "▼  "
    [int]$TREE_INDENT = 7        # "    └─ " for subtasks
    [int]$SUBTASK_INDENT = 4     # "    " spacing
    
    # Legacy column widths (kept for compatibility)
    [int]$COLUMN_STATUS = 4      # Now ID1
    [int]$COLUMN_PRIORITY = 13   # Now ID2
    [int]$StatusCol = 4
    [int]$PriorityCol = 13 
    [int]$DateCol = 9
    [int]$ArrowCol = 3
    [int]$IndentWidth = 4
    
    # Built-in color themes - no external dependencies
    # Task colors now use centralized AppThemeManager
    
    # Subtask colors now use centralized AppThemeManager
    
    # Pillbox characters
    [string]$PillboxTopLeft = "╭"
    [string]$PillboxTopRight = "╮"
    [string]$PillboxBottomLeft = "╰"
    [string]$PillboxBottomRight = "╯"
    [string]$PillboxHorizontal = "─"
    [string]$PillboxVertical = "│"
    
    
    
    TaskListScreen([ServiceContainer]$services) : base($services) {
        $this.TaskService = [SimpleTaskService]::new()
        $this.ContentBuilder = [FastLineBuilder]::new()
        $this.LoadData()
    }
    
    
    
    # Self-contained color theme methods - replace ColorThemeService
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
# === DATA MANAGEMENT (implements abstract methods from ListScreen) ===

    

    [array] BuildFlatList() {
        # This method converts your hierarchical tasks into a flat list for rendering.
        # The logic is likely similar to what was in your old BuildFlatList method.
        $newList = [System.Collections.Generic.List[object]]::new()
        
        foreach ($task in $this.Tasks) {
            # Apply filters if you have them
            if (-not $this.ShouldShowTask($task)) { continue }

            $newList.Add( @{ Task = $task; Level = 0; IsLast = $false })

            if (-not $this.GlobalCollapseSubtasks -and -not $task.SubtasksCollapsed -and $task.Subtasks) {
                for ($i = 0; $i -lt $task.Subtasks.Count; $i++) {
                    $subtask = $task.Subtasks[$i]
                    if ($this.ShouldShowTask($subtask)) {
                        $newList.Add( @{ Task = $subtask; Level = 1; IsLast = ($i -eq $task.Subtasks.Count - 1) })
                    }
                }
            }
        }
        return $newList.ToArray()
    }

    [bool] ShouldShowTask([object]$task) {
        # TODO: Implement filtering logic here
        return $true
    }

    [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
        # This method defines how a single row is rendered.
        # It delegates the complex string building to your FastLineBuilder.
        $task = $item.Task
        $level = $item.Level
        $isLast = $item.IsLast

        # Generate the two-line view model (content and tags)
        $viewModel = $this.ContentBuilder.GenerateTaskViewModel($task, $this, $level, $isLast)
        
        # Return both lines, separated by a newline, for the RenderEngine.
        # The base class will handle the rest.
        return "$($viewModel[0])`n$($viewModel[1])"
    }

    [string[]] GetEditableFields([object]$item) {
        # This defines which fields are editable and in what order (for Tab key).
        $task = $item.Task
        if ($task.IsParent()) {
            return @("ID1", "ID2", "Title", "DueDate", "Tags")
        } else {
            return @("Title", "Priority", "DueDate", "Tags")
        }
    }

    [void] SaveItem([object]$item) {
        # This method tells the screen how to save a modified item.
        $task = if ($item -is [hashtable]) { $item.Task } else { $item }
        $this.TaskService.UpdateTask($task) # Or AddTask if it's new
        $this.TaskService.Save()
    }

    [object] CreateNewItem() {
        # This method tells the screen how to create a new, blank item.
        $newTask = [SimpleTask]::new("New Task")
        $this.TaskService.AddTask($newTask)
        
        # IMPORTANT: Return the hashtable structure the FlatList expects
        return @{ Task = $newTask; Level = 0; IsLast = $false }
    }

    # Override in derived classes for screen-specific commands
    [void] HandleDerivedCommand([string]$command) {
        # Ensure we have a selected item for context-sensitive commands
        if ($this.FlatList.Count -eq 0) { return }
        $selectedItem = $this.FlatList[$this.SelectedIndex]
        $task = $selectedItem.Task

        switch ($command) {
            "task.toggle.complete" { # Mapped to 'X'
                $task.Completed = -not $task.Completed
                $this.TaskService.UpdateTask($task)
                $this.TaskService.Save()
                $this.SetStatusMessage("Task '$($task.Title)' marked as $(if($task.Completed){'complete'}else{'incomplete'})", 2000)
            }
            "task.toggle.collapse" { # Mapped to 'Spacebar'
                 if ($task.IsParent()) {
                    $task.SubtasksCollapsed = -not $task.SubtasksCollapsed
                    $this.TaskService.UpdateTask($task)
                    $this.TaskService.Save()
                }
            }
            "task.filter.cycle" { # Mapped to 'F' or similar
                # Add your logic to cycle through filters here
                $this.SetStatusMessage("Filter changed...", 2000)
            }
            "app.theme.cycle" { # Mapped to 'T' or similar
                $newTheme = [AppThemeManager]::CycleTheme()
                $this.SetStatusMessage("Theme set to $newTheme", 2000)
            }
            default {
                # Let the base class know if we didn't handle it
                [super]::HandleDerivedCommand($command)
            }
        }
        
        # Refresh the list to show the changes
        $this.RefreshList()
    }

}

# TaskScreen.ps1 - Task management screen using DataGrid

class TaskScreen : Screen {
    [DataGrid]$TaskGrid
    [TaskService]$TaskService
    [SubtaskService]$SubtaskService
    [ProjectService]$ProjectService
    [hashtable]$StatusColors
    [hashtable]$PriorityColors
    [EventBus]$EventBus
    hidden [hashtable]$EventSubscriptions = @{}
    hidden [bool]$ShowSubtasks = $true
    hidden [hashtable]$ProjectCache = @{}
    
    # Layout settings
    hidden [int]$StatusBarHeight = 2
    
    TaskScreen() : base() {
        $this.Title = "Tasks"
    }
    
    [void] OnInitialize() {
        # Get services using proper dependency injection
        $this.TaskService = $this.GetService("TaskService")
        if (-not $this.TaskService) {
            $this.TaskService = [TaskService]::new()
            if ($this.ServiceContainer) {
                $this.ServiceContainer.Register("TaskService", $this.TaskService)
            } else {
                $global:ServiceContainer.Register("TaskService", $this.TaskService)
            }
        }
        
        $this.SubtaskService = $this.GetService("SubtaskService")
        if (-not $this.SubtaskService) {
            $this.SubtaskService = [SubtaskService]::new()
            if ($this.ServiceContainer) {
                $this.ServiceContainer.Register("SubtaskService", $this.SubtaskService)
            } else {
                $global:ServiceContainer.Register("SubtaskService", $this.SubtaskService)
            }
        }
        
        $this.ProjectService = $this.GetService("ProjectService")
        $this.EventBus = $this.GetService('EventBus')
        
        # Subscribe to events
        if ($this.EventBus) {
            # Capture reference to this screen instance
            $screen = $this
            
            # Subscribe to task created events
            $this.EventSubscriptions['TaskCreated'] = $this.EventBus.Subscribe('task.created', {
                param($sender, $eventData)
                $screen.LoadTasks()
                # Select the new task if provided
                if ($eventData.Task) {
                    for ($i = 0; $i -lt $screen.TaskGrid.Items.Count; $i++) {
                        if ($screen.TaskGrid.Items[$i].Id -eq $eventData.Task.Id) {
                            $screen.TaskGrid.SelectIndex($i)
                            break
                        }
                    }
                }
            }.GetNewClosure())
            
            # Subscribe to command events for this screen
            $this.EventSubscriptions['CommandExecuted'] = $this.EventBus.Subscribe('command.executed', {
                param($sender, $eventData)
                if ($global:Logger) {
                    $global:Logger.Debug("TaskScreen: Received CommandExecuted event - Command: $($eventData.Command), Target: $($eventData.Target)")
                }
                if ($eventData.Target -eq 'TaskScreen') {
                    switch ($eventData.Command) {
                        'NewTask' { 
                            if ($global:Logger) {
                                $global:Logger.Debug("TaskScreen: Executing NewTask command")
                            }
                            $screen.NewTask() 
                        }
                        'EditTask' { $screen.EditTask() }
                        'DeleteTask' { $screen.DeleteTask() }
                    }
                }
            }.GetNewClosure())
            
            # Subscribe to task updated events
            $this.EventSubscriptions['TaskUpdated'] = $this.EventBus.Subscribe('task.updated', {
                param($sender, $eventData)
                $screen.LoadTasks()
            }.GetNewClosure())
            
            # Subscribe to task deleted events
            $this.EventSubscriptions['TaskDeleted'] = $this.EventBus.Subscribe('task.deleted', {
                param($sender, $eventData)
                $screen.LoadTasks()
            }.GetNewClosure())
        }
        
        # Set up color mappings
        $this.StatusColors = @{
            [TaskStatus]::Pending = "foreground"
            [TaskStatus]::InProgress = "warning"
            [TaskStatus]::Completed = "success"
            [TaskStatus]::Cancelled = "disabled"
        }
        
        $this.PriorityColors = @{
            [TaskPriority]::Low = "success"
            [TaskPriority]::Medium = "warning"
            [TaskPriority]::High = "error"
        }
        
        # Create DataGrid with columns
        $this.TaskGrid = [DataGrid]::new()
        $this.TaskGrid.Title = "Tasks"
        $this.TaskGrid.ShowBorder = $true
        $this.TaskGrid.ShowGridLines = $true
        
        # Define columns
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
        
        $this.TaskGrid.SetColumns($columns)
        $this.TaskGrid.Initialize($global:ServiceContainer)
        $this.AddChild($this.TaskGrid)
        
        # Load tasks
        $this.LoadTasks()
    }
    
    
    [void] OnActivated() {
        # Call base to manage focus scope and shortcuts
        ([Screen]$this).OnActivated()
        
        # Focus the grid
        if ($this.TaskGrid -and $this.TaskGrid.Items.Count -gt 0) {
            $this.TaskGrid.Focus()
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("TaskScreen.OnActivated: Screen activated and focused grid")
        }
    }
    
    [void] OnBoundsChanged() {
        # Layout: Grid takes all space except status bar
        $gridHeight = $this.Height - $this.StatusBarHeight
        
        # Task grid
        $this.TaskGrid.SetBounds(
            $this.X,
            $this.Y,
            $this.Width,
            $gridHeight
        )
    }
    
    [void] LoadTasks() {
        $tasks = $this.TaskService.GetAllTasks()
        
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
            
            $this.TaskGrid.SetItems($combinedItems)
        } else {
            $this.TaskGrid.SetItems($sorted)
        }
    }
    
    [void] NewTask() {
        # Create new task dialog
        $dialog = [NewTaskDialog]::new()
        
        # EventBus will handle task creation and dialog closing
        # Legacy callbacks are only set as fallback for non-EventBus scenarios
        if (-not $this.EventBus) {
            # Capture the screen reference
            $screen = $this
            $dialog.OnCreate = {
                param($taskData)
                
                $task = $screen.TaskService.CreateTask($taskData)
                $screen.LoadTasks()
                
                # Select the new task
                for ($i = 0; $i -lt $screen.TaskGrid.Items.Count; $i++) {
                    if ($screen.TaskGrid.Items[$i].Id -eq $task.Id) {
                        $screen.TaskGrid.SelectIndex($i)
                        break
                    }
                }
                
                # Don't call Pop() - BaseDialog handles that
            }.GetNewClosure()
            
            # Don't need OnCancel - BaseDialog handles ESC by default
        }
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] EditTask() {
        $selected = $this.TaskGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        # Check if it's a subtask or main task
        if ($selected.PSObject.Properties.Name -contains 'ParentTaskId') {
            # Edit subtask
            $this.EditSubtask($selected)
            return
        }
        
        # Create edit task dialog
        $dialog = [EditTaskDialog]::new($selected)
        # Capture references
        $screen = $this
        $task = $selected
        $dialog.OnSave = {
            param($taskData)
            
            # Update the task
            $task.Title = $taskData.Title
            $task.Description = $taskData.Description
            $task.Status = $taskData.Status
            $task.Priority = $taskData.Priority
            $task.Progress = $taskData.Progress
            $task.UpdatedAt = [DateTime]::Now
            
            # Save through service
            $screen.TaskService.UpdateTask($task)
            
            # Publish task updated event
            if ($screen.EventBus) {
                $screen.EventBus.Publish([EventNames]::TaskUpdated, @{ Task = $task })
            } else {
                # Fallback if EventBus not available
                $screen.LoadTasks()
            }
            
            # EditTaskDialog is not a BaseDialog, so we need to Pop manually
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        # EditTaskDialog is not a BaseDialog, so we need to handle cancel
        $dialog.OnCancel = {
            $screenManager = $screen.ServiceContainer.GetService("ScreenManager")
            if ($screenManager) {
                $screenManager.Pop()
            }
        }.GetNewClosure()
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] DeleteTask() {
        $selected = $this.TaskGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        # Check if it's a subtask or main task
        $isSubtask = $selected.PSObject.Properties.Name -contains 'ParentTaskId'
        $message = if ($isSubtask) {
            "Are you sure you want to delete this subtask?`n`n$($selected.Title)"
        } else {
            "Are you sure you want to delete this task?`n`n$($selected.Title)"
        }
        
        # Show confirmation dialog
        $dialog = [ConfirmationDialog]::new($message)
        # Capture references
        $screen = $this
        $itemId = $selected.Id
        $dialog.OnConfirm = {
            if ($isSubtask) {
                # Delete subtask
                $screen.SubtaskService.DeleteSubtask($itemId)
            } else {
                # Delete task (and all its subtasks)
                $screen.TaskService.DeleteTask($itemId)
            }
            
            # Publish task deleted event
            if ($screen.EventBus) {
                $screen.EventBus.Publish([EventNames]::TaskDeleted, @{ TaskId = $itemId })
            } else {
                # Fallback if EventBus not available
                $screen.LoadTasks()
            }
            
            # Don't call Pop() - BaseDialog handles that
        }.GetNewClosure()
        
        # Don't need OnCancel - BaseDialog handles ESC by default
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] CycleStatus() {
        $selected = $this.TaskGrid.GetSelectedItem()
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
            $this.TaskService.UpdateTaskStatus($selected.Id, $newStatus)
        }
        
        # Publish task status changed event
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::TaskStatusChanged, @{ 
                TaskId = $selected.Id
                OldStatus = $selected.Status
                NewStatus = $newStatus
            })
        } else {
            # Fallback if EventBus not available
            $this.LoadTasks()
        }
    }
    
    [void] AddSubtask() {
        $selected = $this.TaskGrid.GetSelectedItem()
        if (-not $selected -or -not $this.SubtaskService) { return }
        
        # Find the parent task (if selected item is a subtask, get its parent)
        $parentTask = $null
        if ($selected.PSObject.Properties.Name -contains 'ParentTaskId') {
            # Selected item is a subtask, find its parent
            $parentTask = $this.TaskService.GetTask($selected.ParentTaskId)
        } else {
            # Selected item is a task
            $parentTask = $selected
        }
        
        if (-not $parentTask) { return }
        
        # Create subtask dialog
        $dialog = [SubtaskDialog]::new($parentTask)
        
        # Set up callback for when subtask is saved
        $screen = $this  # Capture reference for closure
        $dialog.OnSave = {
            param($subtaskData)
            
            # Create subtask using service
            $properties = @{
                ParentTaskId = $subtaskData.ParentTaskId
                Title = $subtaskData.Title
                Description = $subtaskData.Description
                Priority = $subtaskData.Priority
                Progress = $subtaskData.Progress
                EstimatedMinutes = $subtaskData.EstimatedMinutes
                ActualMinutes = $subtaskData.ActualMinutes
                DueDate = $subtaskData.DueDate
            }
            
            $screen.SubtaskService.CreateSubtask($properties)
            $screen.LoadTasks()
            
            # Don't call Pop() - BaseDialog handles that
        }.GetNewClosure()
        
        # Don't need OnCancel - BaseDialog handles ESC by default
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] ToggleSubtaskView() {
        $this.ShowSubtasks = -not $this.ShowSubtasks
        $this.LoadTasks()
    }
    
    [void] EditSubtask([PSCustomObject]$subtask) {
        if (-not $subtask -or -not $this.SubtaskService) { return }
        
        # Get parent task for context
        $parentTask = $this.TaskService.GetTask($subtask.ParentTaskId)
        if (-not $parentTask) { return }
        
        # Create subtask dialog for editing
        $dialog = [SubtaskDialog]::new($parentTask, $subtask)
        
        # Set up callback for when subtask is updated
        $screen = $this  # Capture reference for closure
        $dialog.OnSave = {
            param($subtaskData)
            
            # Update the existing subtask
            $subtask.Title = $subtaskData.Title
            $subtask.Description = $subtaskData.Description
            $subtask.Status = $subtaskData.Status
            $subtask.Priority = $subtaskData.Priority
            $subtask.Progress = $subtaskData.Progress
            $subtask.EstimatedMinutes = $subtaskData.EstimatedMinutes
            $subtask.ActualMinutes = $subtaskData.ActualMinutes
            $subtask.DueDate = $subtaskData.DueDate
            $subtask.UpdatedAt = [DateTime]::Now
            
            # Save through service
            $screen.SubtaskService.SaveSubtask($subtask)
            $screen.LoadTasks()
            
            # Don't call Pop() - BaseDialog handles that
        }.GetNewClosure()
        
        # Don't need OnCancel - BaseDialog handles ESC by default
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] CyclePriority() {
        $selected = $this.TaskGrid.GetSelectedItem()
        if (-not $selected) { return }
        
        # Don't cycle priority for subtasks in this view
        if ($selected.PSObject.Properties.Name -contains 'ParentTaskId') { return }
        
        $this.TaskService.CyclePriority($selected.Id)
        $this.LoadTasks()
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        if ($global:Logger) {
            $global:Logger.Debug("TaskScreen.HandleScreenInput: Key=$($key.Key) Char='$($key.KeyChar)'")
        }
        
        # Handle screen-specific shortcuts
        switch ($key.Key) {
            ([System.ConsoleKey]::N) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'N' -or $key.KeyChar -eq 'n')) {
                    $this.NewTask()
                    return $true
                }
            }
            ([System.ConsoleKey]::E) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'E' -or $key.KeyChar -eq 'e')) {
                    $this.EditTask()
                    return $true
                }
            }
            ([System.ConsoleKey]::Enter) {
                $this.EditTask()
                return $true
            }
            ([System.ConsoleKey]::D) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'D' -or $key.KeyChar -eq 'd')) {
                    $this.DeleteTask()
                    return $true
                }
            }
            ([System.ConsoleKey]::Delete) {
                $this.DeleteTask()
                return $true
            }
            ([System.ConsoleKey]::R) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'R' -or $key.KeyChar -eq 'r')) {
                    $this.LoadTasks()
                    return $true
                }
            }
            ([System.ConsoleKey]::F5) {
                $this.LoadTasks()
                return $true
            }
            ([System.ConsoleKey]::S) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'S' -or $key.KeyChar -eq 's')) {
                    $this.CycleStatus()
                    return $true
                }
            }
            ([System.ConsoleKey]::P) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'P' -or $key.KeyChar -eq 'p')) {
                    $this.CyclePriority()
                    return $true
                }
            }
            ([System.ConsoleKey]::A) {
                if ($key.Modifiers -band [ConsoleModifiers]::Shift -and ($key.KeyChar -eq 'A')) {
                    # Shift+A to add subtask
                    $this.AddSubtask()
                    return $true
                }
            }
            ([System.ConsoleKey]::T) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'T' -or $key.KeyChar -eq 't')) {
                    # Toggle subtask view
                    $this.ToggleSubtaskView()
                    return $true
                }
            }
        }
        
        return $false
    }
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Render base (background and children)
        $sb.Append(([Container]$this).OnRender())
        
        # Render status bar
        $statusY = $this.Y + $this.Height - $this.StatusBarHeight
        $sb.Append([VT]::MoveTo($this.X, $statusY))
        $sb.Append($this.Theme.GetColor("border"))
        $sb.Append("─" * $this.Width)
        
        # Status text
        $sb.Append([VT]::MoveTo($this.X + 1, $statusY + 1))
        $sb.Append($this.Theme.GetColor("disabled"))
        
        $selected = $this.TaskGrid.GetSelectedItem()
        if ($selected) {
            # Show task details in status bar
            $isSubtask = $selected.PSObject.Properties.Name -contains 'ParentTaskId'
            $type = if ($isSubtask) { "Subtask" } else { "Task" }
            $status = $selected.Status.ToString()
            $priority = $selected.Priority.ToString()
            $sb.Append("${type}: $($selected.Title) | Status: $status | Priority: $priority")
        } else {
            # Show help text with letter-based shortcuts
            $sb.Append("[N]ew [E]dit [D]elete [S]tatus [P]riority [A+Shift]Subtask [T]oggle [Tab]Navigate")
        }
        
        # Add legend for status/priority letters
        $sb.Append([VT]::MoveTo($this.X + $this.Width - 35, $statusY + 1))
        $sb.Append("S: P=Pending W=Working D=Done X=Cancel")
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
}
# TaskScreen.ps1 - Task management screen using DataGrid

class TaskScreen : Screen {
    [MinimalDataGrid]$TaskGrid
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
    hidden [int]$StatusBarHeight = 0
    
    TaskScreen() : base() {
        $this.Title = "Tasks"
    }
    
    [void] OnInitialize() {
        # Critical debug for freeze investigation
        if ($global:Logger) {
            $global:Logger.Info("TaskScreen.OnInitialize: START")
        }
        
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
        $this.TaskGrid = [MinimalDataGrid]::new()
        $this.TaskGrid.Title = "Tasks"
        $this.TaskGrid.ShowBorder = $true   # Component responsible for own visual boundaries
        $this.TaskGrid.BorderType = [BorderType]::Rounded
        $this.TaskGrid.ShowGridLines = $false
        
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
        
        # Register screen-specific shortcuts
        $this.RegisterShortcuts()
        
        # Critical debug for freeze investigation
        if ($global:Logger) {
            $global:Logger.Info("TaskScreen.OnInitialize: COMPLETED")
        }
    }

    # Remove OnActivated override - base Screen class handles focus properly now
    
    [void] OnBoundsChanged() {
        # Only update bounds if TaskGrid exists
        if (-not $this.TaskGrid) { return }
        
        # Layout: Grid takes all space
        $gridHeight = $this.Height
        
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
        if ($global:Logger) {
            $global:Logger.Info("TaskScreen.NewTask: Creating new task dialog")
        }
        
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
            
            # Don't call Pop() - BaseDialog handles that
        }.GetNewClosure()
        
        # Don't need OnCancel - BaseDialog handles ESC by default
        
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
        $dialog.OnPrimary = {
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
    
    [void] RegisterShortcuts() {
        $shortcutManager = $this.ServiceContainer.GetService('ShortcutManager')
        if (-not $shortcutManager) { 
            if ($global:Logger) {
                $global:Logger.Warning("TaskScreen: ShortcutManager not found")
            }
            return 
        }
        
        # Capture screen reference for closures
        $screen = $this
        
        # Enter: Edit task
        $shortcutManager.RegisterShortcut(@{
            Id = "task.edit_enter"
            Name = "Edit Task"
            Description = "Edit the selected task"
            Key = [System.ConsoleKey]::Enter
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.EditTask() }.GetNewClosure()
        })
        
        # Delete: Delete task
        $shortcutManager.RegisterShortcut(@{
            Id = "task.delete"
            Name = "Delete Task"
            Description = "Delete the selected task"
            Key = [System.ConsoleKey]::Delete
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.DeleteTask() }.GetNewClosure()
        })
        
        # F5: Refresh
        $shortcutManager.RegisterShortcut(@{
            Id = "task.refresh"
            Name = "Refresh"
            Description = "Refresh the task list"
            Key = [System.ConsoleKey]::F5
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.LoadTasks() }.GetNewClosure()
        })
        
        # n: New task
        $shortcutManager.RegisterShortcut(@{
            Id = "task.new"
            Name = "New Task"
            Description = "Create a new task"
            KeyChar = 'n'
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.NewTask() }.GetNewClosure()
        })
        
        # e: Edit task
        $shortcutManager.RegisterShortcut(@{
            Id = "task.edit"
            Name = "Edit Task"
            Description = "Edit the selected task"
            KeyChar = 'e'
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.EditTask() }.GetNewClosure()
        })
        
        # d: Delete task
        $shortcutManager.RegisterShortcut(@{
            Id = "task.delete_key"
            Name = "Delete Task"
            Description = "Delete the selected task"
            KeyChar = 'd'
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.DeleteTask() }.GetNewClosure()
        })
        
        # r: Refresh
        $shortcutManager.RegisterShortcut(@{
            Id = "task.refresh_key"
            Name = "Refresh"
            Description = "Refresh the task list"
            KeyChar = 'r'
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.LoadTasks() }.GetNewClosure()
        })
        
        # s: Cycle status
        $shortcutManager.RegisterShortcut(@{
            Id = "task.cycle_status"
            Name = "Cycle Status"
            Description = "Cycle task status"
            KeyChar = 's'
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.CycleStatus() }.GetNewClosure()
        })
        
        # p: Cycle priority
        $shortcutManager.RegisterShortcut(@{
            Id = "task.cycle_priority"
            Name = "Cycle Priority"
            Description = "Cycle task priority"
            KeyChar = 'p'
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.CyclePriority() }.GetNewClosure()
        })
        
        # t: Toggle subtask view
        $shortcutManager.RegisterShortcut(@{
            Id = "task.toggle_subtasks"
            Name = "Toggle Subtasks"
            Description = "Toggle subtask view"
            KeyChar = 't'
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.ToggleSubtaskView() }.GetNewClosure()
        })
        
        # a: Add subtask
        $shortcutManager.RegisterShortcut(@{
            Id = "task.add_subtask"
            Name = "Add Subtask"
            Description = "Add subtask to selected task"
            KeyChar = 'a'
            Scope = [ShortcutScope]::Screen
            ScreenType = "TaskScreen"
            Priority = 10
            Action = { $screen.AddSubtask() }.GetNewClosure()
        })
        
        if ($global:Logger) {
            $global:Logger.Debug("TaskScreen.RegisterShortcuts: Registered all shortcuts")
        }
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 1024
        
        # Render base (background and children)
        $sb.Append(([Container]$this).OnRender())

        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}
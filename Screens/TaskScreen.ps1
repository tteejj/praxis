# TaskScreen.ps1 - Task management screen

class TaskScreen : Screen {
    [ListBox]$TaskList
    [TextBox]$FilterBox
    [TaskService]$TaskService
    [SubtaskService]$SubtaskService
    [hashtable]$StatusColors
    [hashtable]$PriorityColors
    [EventBus]$EventBus
    hidden [hashtable]$EventSubscriptions = @{}
    hidden [bool]$ShowSubtasks = $true
    
    # Layout settings
    hidden [int]$FilterHeight = 3
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
        
        $this.EventBus = $this.GetService('EventBus')
        
        # Subscribe to events
        if ($this.EventBus) {
            # Capture reference to this screen instance
            $screen = $this
            
            # Subscribe to task created events
            $this.EventSubscriptions['TaskCreated'] = $this.EventBus.Subscribe([EventNames]::TaskCreated, {
                param($sender, $eventData)
                $screen.LoadTasks()
                # Select the new task if provided
                if ($eventData.Task) {
                    for ($i = 0; $i -lt $screen.TaskList.Items.Count; $i++) {
                        if ($screen.TaskList.Items[$i].Id -eq $eventData.Task.Id) {
                            $screen.TaskList.SelectIndex($i)
                            break
                        }
                    }
                }
            }.GetNewClosure())
            
            # Subscribe to command events for this screen
            $this.EventSubscriptions['CommandExecuted'] = $this.EventBus.Subscribe([EventNames]::CommandExecuted, {
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
            $this.EventSubscriptions['TaskUpdated'] = $this.EventBus.Subscribe([EventNames]::TaskUpdated, {
                param($sender, $eventData)
                $screen.LoadTasks()
            }.GetNewClosure())
            
            # Subscribe to task deleted events
            $this.EventSubscriptions['TaskDeleted'] = $this.EventBus.Subscribe([EventNames]::TaskDeleted, {
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
        
        # Create filter box
        $this.FilterBox = [TextBox]::new()
        $this.FilterBox.Placeholder = "Filter tasks... (type to search)"
        $this.FilterBox.ShowBorder = $true
        $taskScreen = $this
        $this.FilterBox.OnChange = {
            param($text)
            $taskScreen.ApplyFilter()
        }.GetNewClosure()
        $this.FilterBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.FilterBox)
        
        # Create task list
        $this.TaskList = [ListBox]::new()
        $this.TaskList.Title = "Tasks"
        $this.TaskList.ShowBorder = $true
        
        # Capture screen reference for ItemRenderer closure
        $screen = $this
        $this.TaskList.ItemRenderer = {
            param($item)
            
            # Check if this is a task or subtask
            if ($item.PSObject.Properties.Name -contains 'ParentTaskId') {
                # This is a subtask
                $subtask = $item
                $status = $subtask.GetStatusDisplay()
                $priority = $subtask.GetPriorityDisplay()
                
                # Build subtask display with indentation
                $display = "    └ $status $priority $($subtask.Title)"
                
                # Add duration if available
                $duration = $subtask.GetDurationDisplay()
                if ($duration) {
                    $display += " [$duration]"
                }
                
                # Add due date indicator if applicable
                if ($subtask.DueDate -ne [DateTime]::MinValue) {
                    $days = $subtask.GetDaysUntilDue()
                    if ($subtask.IsOverdue()) {
                        $display += " [OVERDUE]"
                    } elseif ($days -le 3 -and $days -ge 0) {
                        $display += " [Due in $days days]"
                    }
                }
                
                return $display
            } else {
                # This is a main task
                $task = $item
                $status = $task.GetStatusDisplay()
                $priority = $task.GetPriorityDisplay()
                
                # Build task display string
                $display = "$status $priority $($task.Title)"
                
                # Add subtask count if any (with null check)
                if ($screen.SubtaskService) {
                    $subtaskStats = $screen.SubtaskService.GetTaskStatistics($task.Id)
                    if ($subtaskStats.Total -gt 0) {
                        $completed = $subtaskStats.Completed
                        $total = $subtaskStats.Total
                        $display += " [$completed/$total subtasks]"
                    }
                }
                
                # Add due date indicator if applicable
                if ($task.DueDate -ne [DateTime]::MinValue) {
                    $days = $task.GetDaysUntilDue()
                    if ($task.IsOverdue()) {
                        $display += " [OVERDUE]"
                    } elseif ($days -le 3 -and $days -ge 0) {
                        $display += " [Due in $days days]"
                    }
                }
                
                # Add progress if in progress
                if ($task.Status -eq [TaskStatus]::InProgress -and $task.Progress -gt 0) {
                    $display += " ($($task.Progress)%)"
                }
                
                return $display
            }
        }.GetNewClosure()
        $this.TaskList.Initialize($global:ServiceContainer)
        $this.AddChild($this.TaskList)
        
        # Load tasks
        $this.LoadTasks()
        
        # Initial focus will be handled by FocusManager when screen is activated
        # Remove explicit Focus() call as it will be handled by OnActivated()
    }
    
    
    [void] OnActivated() {
        # Call base to manage focus scope and shortcuts
        ([Screen]$this).OnActivated()
        
        # Explicitly focus the appropriate component
        if ($this.TaskList -and $this.TaskList.Items.Count -gt 0) {
            $this.TaskList.Focus()
        } elseif ($this.FilterBox) {
            $this.FilterBox.Focus()
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("TaskScreen.OnActivated: Screen activated and focused appropriate component")
        }
    }
    
    [void] OnBoundsChanged() {
        # Layout: Filter at top, tasks in middle, status at bottom
        $contentHeight = $this.Height - $this.FilterHeight - $this.StatusBarHeight
        
        # Filter box
        $this.FilterBox.SetBounds(
            $this.X,
            $this.Y,
            $this.Width,
            $this.FilterHeight
        )
        
        # Task list
        $this.TaskList.SetBounds(
            $this.X,
            $this.Y + $this.FilterHeight,
            $this.Width,
            $contentHeight
        )
    }
    
    [void] LoadTasks() {
        $tasks = $this.TaskService.GetAllTasks()
        
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
            
            $this.TaskList.SetItems($combinedItems)
        } else {
            $this.TaskList.SetItems($sorted)
        }
    }
    
    [void] ApplyFilter() {
        $filterText = $this.FilterBox.Text.ToLower()
        
        if ([string]::IsNullOrWhiteSpace($filterText)) {
            $this.LoadTasks()
            return
        }
        
        $tasks = $this.TaskService.GetAllTasks()
        $filtered = $tasks | Where-Object {
            -not $_.Deleted -and (
                $_.Title.ToLower().Contains($filterText) -or
                $_.Description.ToLower().Contains($filterText) -or
                $_.Tags -contains $filterText
            )
        }
        
        # Sort filtered results
        $sorted = $filtered | Sort-Object -Property `
            @{Expression = {$_.Priority}; Descending = $true},
            @{Expression = {$_.Status}; Ascending = $true},
            @{Expression = {if ($_.DueDate -eq [DateTime]::MinValue) { [DateTime]::MaxValue } else { $_.DueDate }}; Ascending = $true}
        
        $this.TaskList.SetItems($sorted)
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
                for ($i = 0; $i -lt $screen.TaskList.Items.Count; $i++) {
                    if ($screen.TaskList.Items[$i].Id -eq $task.Id) {
                        $screen.TaskList.SelectIndex($i)
                        break
                    }
                }
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }.GetNewClosure()
            
            $dialog.OnCancel = {
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }
        }
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] EditTask() {
        $selected = $this.TaskList.GetSelectedItem()
        if (-not $selected) { return }
        
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
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] DeleteTask() {
        $selected = $this.TaskList.GetSelectedItem()
        if (-not $selected) { return }
        
        # Show confirmation dialog
        $message = "Are you sure you want to delete this task?`n`n$($selected.Title)"
        $dialog = [ConfirmationDialog]::new($message)
        # Capture references
        $screen = $this
        $taskId = $selected.Id
        $dialog.OnConfirm = {
            $screen.TaskService.DeleteTask($taskId)
            
            # Publish task deleted event
            if ($screen.EventBus) {
                $screen.EventBus.Publish([EventNames]::TaskDeleted, @{ TaskId = $taskId })
            } else {
                # Fallback if EventBus not available
                $screen.LoadTasks()
            }
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }
        
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] CycleStatus() {
        $selected = $this.TaskList.GetSelectedItem()
        if (-not $selected) { return }
        
        # Cycle through status values
        $newStatus = switch ($selected.Status) {
            ([TaskStatus]::Pending) { [TaskStatus]::InProgress }
            ([TaskStatus]::InProgress) { [TaskStatus]::Completed }
            ([TaskStatus]::Completed) { [TaskStatus]::Cancelled }
            ([TaskStatus]::Cancelled) { [TaskStatus]::Pending }
        }
        
        $this.TaskService.UpdateTaskStatus($selected.Id, $newStatus)
        
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
        $selected = $this.TaskList.GetSelectedItem()
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
            
            # Close dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }.GetNewClosure()
        
        $dialog.OnCancel = {
            # Close dialog
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }
        
        # Show dialog
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] ToggleSubtaskView() {
        $this.ShowSubtasks = -not $this.ShowSubtasks
        $this.LoadTasks()
    }
    
    [void] CyclePriority() {
        $selected = $this.TaskList.GetSelectedItem()
        if (-not $selected) { return }
        
        $this.TaskService.CyclePriority($selected.Id)
        $this.LoadTasks()
    }
    
    # FocusNext method removed - Tab navigation now handled by FocusManager service
    
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
            ([System.ConsoleKey]::F) {
                if (-not $key.Modifiers -and ($key.KeyChar -eq 'F' -or $key.KeyChar -eq 'f')) {
                    $this.FilterBox.Focus()
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
            ([System.ConsoleKey]::Escape) {
                if ($this.FilterBox.IsFocused -and $this.FilterBox.Text) {
                    $this.FilterBox.Clear()
                    $this.ApplyFilter()
                    $this.TaskList.Focus()
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
        
        # Show focus indicator
        $focused = $this.FindFocused()
        $focusInfo = if ($focused -eq $this.FilterBox) { "[FILTER]" } elseif ($focused -eq $this.TaskList) { "[LIST]" } else { "[NONE]" }
        
        $selected = $this.TaskList.GetSelectedItem()
        if ($selected) {
            # Show task details in status bar
            $sb.Append("$focusInfo Task: $($selected.Title) | Status: $($selected.Status) | Priority: $($selected.Priority)")
        } else {
            # Show help text
            $sb.Append("$focusInfo [N]ew [E]dit [D]elete [S]tatus [P]riority [/]Filter [Tab]Navigate")
        }
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
}
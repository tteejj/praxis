# TaskScreen.ps1 - Task management screen

class TaskScreen : Screen {
    [ListBox]$TaskList
    [TextBox]$FilterBox
    [TaskService]$TaskService
    [hashtable]$StatusColors
    [hashtable]$PriorityColors
    [EventBus]$EventBus
    hidden [hashtable]$EventSubscriptions = @{}
    
    # Layout settings
    hidden [int]$FilterHeight = 3
    hidden [int]$StatusBarHeight = 2
    
    TaskScreen() : base() {
        $this.Title = "Tasks"
    }
    
    [void] OnInitialize() {
        # Get services
        $this.TaskService = $global:ServiceContainer.GetService("TaskService")
        if (-not $this.TaskService) {
            $this.TaskService = [TaskService]::new()
            $global:ServiceContainer.Register("TaskService", $this.TaskService)
        }
        
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Subscribe to events
        if ($this.EventBus) {
            # Subscribe to task created events
            $this.EventSubscriptions['TaskCreated'] = $this.EventBus.Subscribe([EventNames]::TaskCreated, {
                param($sender, $eventData)
                $this.LoadTasks()
                # Select the new task if provided
                if ($eventData.Task) {
                    for ($i = 0; $i -lt $this.TaskList.Items.Count; $i++) {
                        if ($this.TaskList.Items[$i].Id -eq $eventData.Task.Id) {
                            $this.TaskList.SelectIndex($i)
                            break
                        }
                    }
                }
            }.GetNewClosure())
            
            # Subscribe to command events for this screen
            $this.EventSubscriptions['CommandExecuted'] = $this.EventBus.Subscribe([EventNames]::CommandExecuted, {
                param($sender, $eventData)
                if ($eventData.Target -eq 'TaskScreen') {
                    switch ($eventData.Command) {
                        'NewTask' { $this.NewTask() }
                        'EditTask' { $this.EditTask() }
                        'DeleteTask' { $this.DeleteTask() }
                    }
                }
            }.GetNewClosure())
            
            # Subscribe to task updated events
            $this.EventSubscriptions['TaskUpdated'] = $this.EventBus.Subscribe([EventNames]::TaskUpdated, {
                param($sender, $eventData)
                $this.LoadTasks()
            }.GetNewClosure())
            
            # Subscribe to task deleted events
            $this.EventSubscriptions['TaskDeleted'] = $this.EventBus.Subscribe([EventNames]::TaskDeleted, {
                param($sender, $eventData)
                $this.LoadTasks()
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
        $this.TaskList.ItemRenderer = {
            param($task)
            $status = $task.GetStatusDisplay()
            $priority = $task.GetPriorityDisplay()
            
            # Build display string
            $display = "$status $priority $($task.Title)"
            
            # Add due date indicator if applicable
            if ($task.DueDate -ne [DateTime]::MinValue) {
                $days = $task.GetDaysUntilDue()
                if ($task.IsOverdue()) {
                    $display += " [OVERDUE]"
                } elseif ($days -le 3) {
                    $display += " [Due in $days days]"
                }
            }
            
            # Add progress if in progress
            if ($task.Status -eq [TaskStatus]::InProgress -and $task.Progress -gt 0) {
                $display += " ($($task.Progress)%)"
            }
            
            return $display
        }
        $this.TaskList.Initialize($global:ServiceContainer)
        $this.AddChild($this.TaskList)
        
        # Load tasks
        $this.LoadTasks()
        
        # Key bindings
        $this.BindKey('n', { $this.NewTask() })
        $this.BindKey('e', { $this.EditTask() })
        $this.BindKey([System.ConsoleKey]::Enter, { $this.EditTask() })
        $this.BindKey('d', { $this.DeleteTask() })
        $this.BindKey([System.ConsoleKey]::Delete, { $this.DeleteTask() })
        $this.BindKey('r', { $this.LoadTasks() })
        $this.BindKey([System.ConsoleKey]::F5, { $this.LoadTasks() })
        $this.BindKey('s', { $this.CycleStatus() })
        $this.BindKey('p', { $this.CyclePriority() })
        $this.BindKey('f', { $this.FilterBox.Focus() })  # 'f' for filter
        $this.BindKey([System.ConsoleKey]::Tab, { $this.FocusNext() })
        $this.BindKey([System.ConsoleKey]::Escape, {
            if ($this.FilterBox.IsFocused -and $this.FilterBox.Text) {
                $this.FilterBox.Clear()
                $this.ApplyFilter()
                $this.TaskList.Focus()
            }
        })
        
        # Focus on task list
        $this.TaskList.Focus()
    }
    
    [void] OnActivated() {
        # Call base to trigger render
        ([Screen]$this).OnActivated()
        
        # Make sure task list has focus when screen is activated
        if ($this.TaskList) {
            # Ensure the TaskScreen itself is focused first
            $this.Focus()
            
            # Then focus the TaskList
            $this.TaskList.Focus()
            if ($global:Logger) {
                $global:Logger.Debug("TaskScreen.OnActivated: Focused TaskList")
                $focused = $this.FindFocused()
                $global:Logger.Debug("TaskScreen.OnActivated: Currently focused element: $($focused.GetType().Name)")
            }
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
        
        $this.TaskList.SetItems($sorted)
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
    
    [void] CyclePriority() {
        $selected = $this.TaskList.GetSelectedItem()
        if (-not $selected) { return }
        
        $this.TaskService.CyclePriority($selected.Id)
        $this.LoadTasks()
    }
    
    [void] FocusNext() {
        $focused = $this.FindFocused()
        
        if ($global:Logger) {
            $global:Logger.Debug("TaskScreen.FocusNext: Currently focused: $($focused.GetType().Name)")
            $global:Logger.Debug("TaskScreen.FocusNext: FilterBox.IsFocused=$($this.FilterBox.IsFocused), TaskList.IsFocused=$($this.TaskList.IsFocused)")
        }
        
        if ($focused -eq $this.FilterBox) {
            # Focus TaskList (Focus() method will handle unfocusing FilterBox)
            $this.TaskList.Focus()
            if ($global:Logger) {
                $global:Logger.Debug("TaskScreen: Switched focus from FilterBox to TaskList")
            }
        } elseif ($focused -eq $this.TaskList) {
            # Focus FilterBox (Focus() method will handle unfocusing TaskList)
            $this.FilterBox.Focus()
            if ($global:Logger) {
                $global:Logger.Debug("TaskScreen: Switched focus from TaskList to FilterBox")
            }
        } else {
            # Neither has focus, focus the list first
            $this.TaskList.Focus()
            if ($global:Logger) {
                $global:Logger.Debug("TaskScreen: No child focused, focusing TaskList")
            }
        }
        
        # Verify focus was actually changed
        $newFocused = $this.FindFocused()
        if ($global:Logger) {
            $global:Logger.Debug("TaskScreen.FocusNext: After switch, focused: $($newFocused.GetType().Name)")
            $global:Logger.Debug("TaskScreen.FocusNext: After switch - FilterBox.IsFocused=$($this.FilterBox.IsFocused), TaskList.IsFocused=$($this.TaskList.IsFocused)")
        }
        
        # Force re-render to show focus change
        $this.Invalidate()
        if ($global:ScreenManager) {
            $global:ScreenManager.RequestRender()
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($global:Logger) {
            $global:Logger.Debug("TaskScreen.HandleInput: Key=$($key.Key) Char='$($key.KeyChar)'")
        }
        
        # Let base class handle key bindings first
        if (([Screen]$this).HandleInput($key)) {
            if ($global:Logger) {
                $global:Logger.Debug("TaskScreen: Input handled by Screen base class")
            }
            return $true
        }
        
        # Otherwise let Container handle focused child input
        return ([Container]$this).HandleInput($key)
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
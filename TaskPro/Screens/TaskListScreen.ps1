# TaskListScreen.ps1 - Simple task list with subtasks

class TaskListScreen {
    [SimpleTaskService]$TaskService
    [SimpleTask[]]$Tasks
    [System.Collections.Generic.List[object]]$FlatList  # Flattened list for navigation
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [int]$Width
    [int]$Height
    [bool]$GlobalCollapseSubtasks = $false
    
    # Modern RGB Colors
    [string]$HeaderColor = "`e[38;2;100;150;255m"     # Modern blue
    [string]$HighColor = "`e[38;2;255;100;100m"       # Coral red
    [string]$MediumColor = "`e[38;2;255;165;0m"       # Orange
    [string]$LowColor = "`e[38;2;80;200;120m"         # Green
    [string]$SubtaskColor = "`e[38;2;160;160;160m"    # Medium gray
    [string]$SelectedBg = "`e[48;2;45;45;55m"         # Dark background highlight
    [string]$EvenRowBg = "`e[48;2;25;25;30m"          # Subtle dark background
    [string]$CompletedColor = "`e[38;2;120;120;120m"  # Medium gray
    [string]$TagColor = "`e[38;2;180;180;180m"        # Light gray for tags
    [string]$NormalColor = "`e[0m"                     # Reset
    
    # Date colors
    [string]$OverdueColor = "`e[38;2;255;100;100m"    # Red
    [string]$WeekColor = "`e[38;2;255;165;0m"          # Orange
    [string]$TodayColor = "`e[38;2;255;255;100m"       # Yellow
    [string]$FutureColor = "`e[38;2;80;200;120m"       # Green
    
    # Column widths for new layout
    [int]$StatusCol = 2      # "☐ "
    [int]$PriorityCol = 4    # "High"
    [int]$DateCol = 11       # "yyyy-mm-dd "
    [int]$ArrowCol = 2       # "▼ "
    [int]$IndentWidth = 4    # "    " for subtasks
    
    TaskListScreen() {
        $this.TaskService = [SimpleTaskService]::new()
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        $this.LoadTasks()
    }
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] LoadTasks() {
        $this.Tasks = $this.TaskService.GetParentTasks()
        $this.BuildFlatList()
        
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
    }
    
    [string] GetDateColorAndText([SimpleTask]$task) {
        if ($task.DueDate -eq [datetime]::MinValue) {
            return $this.TagColor + "-".PadRight($this.DateCol - 1) + $this.NormalColor
        }
        
        $today = [datetime]::Today
        $due = $task.DueDate.Date
        $daysDiff = ($due - $today).Days
        
        $dateText = $due.ToString("yyyy-MM-dd")
        $color = if ($daysDiff -lt 0) { $this.OverdueColor }
                elseif ($daysDiff -eq 0) { $this.TodayColor }
                elseif ($daysDiff -le 7) { $this.WeekColor }
                else { $this.FutureColor }
        
        return $color + $dateText + $this.NormalColor
    }

    [void] BuildFlatList() {
        $this.FlatList.Clear()
        
        foreach ($task in $this.Tasks) {
            # Add parent task
            $this.FlatList.Add(@{
                Task = $task
                Level = 0
                IsLast = $false
            })
            
            # Add subtasks only if not collapsed (check both global and task-specific)
            $shouldShowSubtasks = -not $this.GlobalCollapseSubtasks -and -not $task.SubtasksCollapsed
            if ($shouldShowSubtasks -and $task.Subtasks.Count -gt 0) {
                for ($i = 0; $i -lt $task.Subtasks.Count; $i++) {
                    $subtask = $task.Subtasks[$i]
                    $isLast = ($i -eq $task.Subtasks.Count - 1)
                    
                    $this.FlatList.Add(@{
                        Task = $subtask
                        Level = 1
                        IsLast = $isLast
                    })
                }
            }
        }
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen
        [void]$sb.Append([VT]::Clear())
        
        # Header
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append("TASKPRO - Task Manager")
        [void]$sb.Append($this.NormalColor)
        
        # Column headers
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append($this.TagColor)
        [void]$sb.Append("St")
        [void]$sb.Append(" " * ($this.StatusCol - 2))
        [void]$sb.Append("Pri ")
        [void]$sb.Append(" " * ($this.PriorityCol - 4))
        [void]$sb.Append("Date       ")
        [void]$sb.Append(" " * ($this.DateCol - 11))
        [void]$sb.Append("  Title")
        [void]$sb.Append($this.NormalColor)
        
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append("═" * $this.Width)
        
        # Task list
        $this.RenderTaskList($sb)
        
        # Status bar
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 2))
        [void]$sb.Append("═" * $this.Width)
        
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
        [void]$sb.Append($this.TagColor)
        [void]$sb.Append("↑↓:Navigate  Ctrl+↑↓:Move  Space:Collapse  C:Collapse All  X:Toggle  Enter:Notes  T:Theme  R:Tags  Q:Quit")
        [void]$sb.Append($this.NormalColor)
        
        # Hide cursor
        [void]$sb.Append([VT]::HideCursor())
        
        return $sb.ToString()
    }
    
    [void] RenderTaskList([System.Text.StringBuilder]$sb) {
        $listHeight = $this.Height - 5  # Header + column header + status bar
        $startY = 3
        
        # Calculate column positions
        $titleStart = $this.StatusCol + $this.PriorityCol
        $titleWidth = $this.Width - $titleStart - $this.DueDateCol - 2
        
        # Calculate visible range
        $endIndex = [Math]::Min($this.ScrollTop + $listHeight, $this.FlatList.Count)
        
        for ($i = $this.ScrollTop; $i -lt $endIndex; $i++) {
            $item = $this.FlatList[$i]
            $task = $item.Task
            $level = $item.Level
            $isLast = $item.IsLast
            $y = $startY + ($i - $this.ScrollTop)
            $isSelected = ($i -eq $this.SelectedIndex)
            
            [void]$sb.Append([VT]::MoveTo(0, $y))
            
            # Row background (alternating + selection)
            if ($isSelected) {
                [void]$sb.Append($this.SelectedBg)
            } elseif ($i % 2 -eq 0) {
                [void]$sb.Append($this.EvenRowBg)
            }
            
            # === COLUMN 1: STATUS (3 chars) ===
            if ($level -eq 0 -and $task.Subtasks.Count -gt 0) {
                if ($this.GlobalCollapseSubtasks -or $task.SubtasksCollapsed) {
                    [void]$sb.Append("▶")  # Collapsed
                } else {
                    [void]$sb.Append("▼")  # Expanded
                }
            } else {
                [void]$sb.Append(" ")
            }
            [void]$sb.Append($task.GetStatusIcon())
            [void]$sb.Append(" ")
            
            # === COLUMN 2: PRIORITY (8 chars) ===
            if ($level -eq 0) {
                $priorityText = $task.GetPriorityDisplay()
                $priorityColor = switch ($task.Priority) {
                    "High" { $this.HighColor }
                    "Medium" { $this.MediumColor }
                    "Low" { $this.LowColor }
                    default { $this.TagColor }
                }
                [void]$sb.Append($priorityColor)
                [void]$sb.Append($priorityText.PadRight($this.PriorityCol))
                [void]$sb.Append($this.NormalColor)
            } else {
                [void]$sb.Append(" " * $this.PriorityCol)
            }
            
            # === COLUMN 3: TITLE & TAGS (flexible width) ===
            # Indentation for subtasks
            if ($level -eq 1) {
                if ($isLast) {
                    [void]$sb.Append("└─ ")
                } else {
                    [void]$sb.Append("├─ ")
                }
            } else {
                [void]$sb.Append("   ")
            }
            
            # Task title color
            if ($task.Completed) {
                $taskColor = $this.CompletedColor
            } elseif ($level -eq 1) {
                $parentTask = $this.TaskService.GetParentTask($task.Id)
                if ($parentTask) {
                    $taskColor = [ColorThemeService]::GetSubtaskColor($parentTask.SubtaskColorTheme)
                } else {
                    $taskColor = $this.SubtaskColor
                }
            } else {
                $taskColor = [ColorThemeService]::GetTaskColor($task.ColorTheme)
            }
            
            [void]$sb.Append($taskColor)
            
            # Title
            $titleText = $task.Title
            $availableWidth = $titleWidth - 3  # Account for indentation
            
            # Calculate text length without color codes for padding
            $displayLength = $task.Title.Length
            
            # Truncate title if needed (before adding tags)
            if ($titleText.Length -gt $availableWidth - 10) {  # Leave room for tags
                $titleText = $titleText.Substring(0, $availableWidth - 11) + "…"
                $displayLength = $titleText.Length
            }
            
            [void]$sb.Append($titleText)
            
            # Add tags in a subtle color
            if ($task.Tags.Count -gt 0) {
                [void]$sb.Append(" ")
                [void]$sb.Append($this.TagColor)
                [void]$sb.Append("#" + ($task.Tags -join " #"))
                [void]$sb.Append($taskColor)
                $displayLength += ($task.Tags -join " #").Length + 2  # Tags + " #"
            }
            
            [void]$sb.Append($this.NormalColor)
            
            # Pad to end of title column
            $padding = [Math]::Max(0, $availableWidth - $displayLength)
            [void]$sb.Append(" " * $padding)
            
            # === COLUMN 4: DUE DATE (10 chars) ===
            if ($level -eq 0) {
                $dueDateText = $task.GetDueDateDisplay()
                [void]$sb.Append($this.TagColor)
                [void]$sb.Append($dueDateText.PadRight($this.DueDateCol))
                [void]$sb.Append($this.NormalColor)
            }
            
            # Clear to end of line and reset colors
            [void]$sb.Append(" " * 2)
            [void]$sb.Append($this.NormalColor)
        }
        
        # Clear remaining lines
        for ($y = $endIndex - $this.ScrollTop + $startY; $y -lt ($this.Height - 2); $y++) {
            [void]$sb.Append([VT]::MoveTo(0, $y))
            [void]$sb.Append(" " * $this.Width)
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                # Check for Ctrl+Up (move task up)
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    if ($this.FlatList.Count -gt 0) {
                        $item = $this.FlatList[$this.SelectedIndex]
                        $taskId = $item.Task.Id
                        if ($global:Debug) { Write-Host "Moving task up: $taskId (current selection: $($this.SelectedIndex))" -ForegroundColor Cyan }
                        
                        $this.TaskService.MoveTaskUp($taskId)
                        $this.LoadTasks()
                        
                        # Find the moved task in the new list and select it
                        $newIndex = -1
                        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                            if ($this.FlatList[$i].Task.Id -eq $taskId) {
                                $newIndex = $i
                                break
                            }
                        }
                        
                        if ($newIndex -ge 0) {
                            $this.SelectedIndex = $newIndex
                            if ($global:Debug) { Write-Host "Task found at new index: $newIndex" -ForegroundColor Green }
                        } else {
                            if ($global:Debug) { Write-Host "Warning: Task not found after move, keeping current selection" -ForegroundColor Red }
                            # Ensure we don't go out of bounds
                            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
                            }
                        }
                        $this.EnsureVisible()
                    }
                } else {
                    # Normal navigation
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                        $this.EnsureVisible()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                # Check for Ctrl+Down (move task down)
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    if ($this.FlatList.Count -gt 0) {
                        $item = $this.FlatList[$this.SelectedIndex]
                        $taskId = $item.Task.Id
                        if ($global:Debug) { Write-Host "Moving task down: $taskId (current selection: $($this.SelectedIndex))" -ForegroundColor Cyan }
                        
                        $this.TaskService.MoveTaskDown($taskId)
                        $this.LoadTasks()
                        
                        # Find the moved task in the new list and select it
                        $newIndex = -1
                        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                            if ($this.FlatList[$i].Task.Id -eq $taskId) {
                                $newIndex = $i
                                break
                            }
                        }
                        
                        if ($newIndex -ge 0) {
                            $this.SelectedIndex = $newIndex
                            if ($global:Debug) { Write-Host "Task found at new index: $newIndex" -ForegroundColor Green }
                        } else {
                            if ($global:Debug) { Write-Host "Warning: Task not found after move, keeping current selection" -ForegroundColor Red }
                            # Ensure we don't go out of bounds
                            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
                            }
                        }
                        $this.EnsureVisible()
                    }
                } else {
                    # Normal navigation
                    if ($this.SelectedIndex -lt ($this.FlatList.Count - 1)) {
                        $this.SelectedIndex++
                        $this.EnsureVisible()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Spacebar) {
                # Toggle individual task collapse (only if it's a parent with subtasks)
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    if ($item.Level -eq 0 -and $item.Task.Subtasks.Count -gt 0) {
                        $item.Task.SubtasksCollapsed = -not $item.Task.SubtasksCollapsed
                        $this.TaskService.UpdateTask($item.Task)
                        $this.LoadTasks()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                # Open notes editor
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    $parentTask = $this.TaskService.GetParentTask($item.Task.Id)
                    if ($parentTask) {
                        return $this.EditNotes($parentTask)
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::N) {
                $this.CreateNewTask()
                return $true
            }
            ([System.ConsoleKey]::S) {
                $this.CreateSubtask()
                return $true
            }
            ([System.ConsoleKey]::D) {
                $this.DeleteTask()
                return $true
            }
            ([System.ConsoleKey]::C) {
                # Toggle global collapse (collapse all subtasks)
                $this.GlobalCollapseSubtasks = -not $this.GlobalCollapseSubtasks
                $this.LoadTasks()
                return $true
            }
            ([System.ConsoleKey]::X) {
                # Toggle task completion
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    $this.TaskService.ToggleComplete($item.Task.Id)
                    $this.LoadTasks()
                }
                return $true
            }
            ([System.ConsoleKey]::T) {
                # Toggle color theme for current task
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    if ($item.Level -eq 0) {
                        # Parent task - cycle through themes
                        $task = $item.Task
                        $task.ColorTheme = [ColorThemeService]::GetNextTheme($task.ColorTheme)
                        $task.SubtaskColorTheme = $task.ColorTheme  # Keep subtasks same theme
                        $this.TaskService.UpdateTask($task)
                        $this.LoadTasks()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::R) {
                # Edit tags for current task (parent or subtask separately)
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    # Always edit the currently selected task's tags, whether parent or subtask
                    $this.EditTaskTags($item.Task)
                }
                return $true
            }
            ([System.ConsoleKey]::Q) {
                return $false
            }
        }
        
        return $true
    }
    
    [void] EnsureVisible() {
        $listHeight = $this.Height - 4
        
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollTop + $listHeight)) {
            $this.ScrollTop = $this.SelectedIndex - $listHeight + 1
        }
    }
    
    [bool] EditNotes([SimpleTask]$parentTask) {
        # Create full-screen editor (leave room for header and status)
        $editor = [FullNotesEditor]::new()
        $editor.SetBounds(0, 2, $this.Width, $this.Height - 3)
        
        # Auto-recover from crash if available
        $recoveredText = $editor.RecoverAutoSave()
        if ($recoveredText) {
            # Automatically use recovered text
            $editor.SetText($recoveredText)
        } else {
            $editor.SetText($parentTask.Notes)
        }
        
        # Show editor header immediately
        [Console]::Clear()
        [Console]::SetCursorPosition(0, 0)
        Write-Host -NoNewline "$($this.HeaderColor)EDITING NOTES: $($parentTask.Title)$($this.NormalColor)"
        [Console]::SetCursorPosition(0, 1)
        Write-Host -NoNewline ("═" * $this.Width)
        [Console]::SetCursorPosition(0, $this.Height - 1)
        Write-Host -NoNewline "Ctrl+S:Save  Escape:Exit  " -ForegroundColor White
        
        # Initial render
        Write-Host -NoNewline $editor.Render()
        
        # Edit loop
        [Console]::CursorVisible = $true
        $saved = $false
        $lastAutoSave = [datetime]::Now
        
        # Set global reference for crash recovery
        $global:CurrentEditor = $editor
        
        try {
            while ($true) {
                # Check for key available (non-blocking for auto-save)
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    
                    if ($key.Key -eq [System.ConsoleKey]::Escape) {
                        # Always auto-save on exit
                        if ($editor.HasUnsavedChanges()) {
                            $parentTask.Notes = $editor.GetText()
                            $this.TaskService.UpdateTask($parentTask)
                            $saved = $true
                        }
                        break
                    } elseif ($key.Key -eq [System.ConsoleKey]::S -and 
                             ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
                        # Manual save with immediate feedback
                        [Console]::SetCursorPosition(0, $this.Height - 1)
                        Write-Host -NoNewline "Saving..." -ForegroundColor Green -BackgroundColor DarkGreen
                        
                        $parentTask.Notes = $editor.GetText()
                        $this.TaskService.UpdateTask($parentTask)
                        $saved = $true
                        
                        # Show save confirmation immediately
                        [Console]::SetCursorPosition(0, $this.Height - 1)
                        Write-Host -NoNewline "Saved!                                            " -ForegroundColor Green -BackgroundColor DarkGreen
                    } else {
                        if ($editor.HandleInput($key)) {
                            # Re-render the editor after handling input
                            Write-Host -NoNewline $editor.Render()
                        }
                    }
                }
                
                # Auto-save every 10 seconds (silent)
                if (([datetime]::Now - $lastAutoSave).TotalSeconds -gt 10) {
                    $editor.AutoSaveIfNeeded()
                    $lastAutoSave = [datetime]::Now
                }
                
                # Small sleep to prevent CPU spinning
                Start-Sleep -Milliseconds 50
            }
        } finally {
            # Always call OnExit to ensure auto-save
            $editor.OnExit()
            
            # If we saved, ensure atomic save to actual task
            if ($saved -or $editor.HasUnsavedChanges()) {
                $parentTask.Notes = $editor.GetText()
                $this.TaskService.UpdateTask($parentTask)
            }
            
            [Console]::CursorVisible = $false
            
            # Clear global reference
            $global:CurrentEditor = $null
            
            # Force refresh of task list
            $this.LoadTasks()
        }
        
        return $true
    }
    
    [bool] EditTaskTags([SimpleTask]$task) {
        # Check if we're in an interactive console environment
        try {
            $testAvailable = [Console]::KeyAvailable
            $testCursor = [Console]::CursorVisible
        } catch {
            # Not in interactive console - fall back to simple text input
            if ($global:Debug) { Write-Host "Console not interactive, using fallback tag editor" -ForegroundColor Yellow }
            return $this.EditTagsFallback($task)
        }
        
        # Create tag editor
        $editor = [TagEditor]::new()
        $editorWidth = [Math]::Min(60, $this.Width - 10)
        $editorHeight = 4
        $editorX = ($this.Width - $editorWidth) / 2
        $editorY = ($this.Height - $editorHeight) / 2
        
        $editor.SetBounds($editorX, $editorY, $editorWidth, $editorHeight)
        $editor.SetTags($task.Tags)
        
        # Save original screen content (simplified)
        $originalCursor = [Console]::CursorVisible
        [Console]::CursorVisible = $true
        
        try {
            while ($true) {
                # Clear editor area and render
                for ($y = $editorY; $y -lt ($editorY + $editorHeight); $y++) {
                    [Console]::SetCursorPosition(0, $y)
                    Write-Host -NoNewline (" " * $this.Width)
                }
                
                # Render editor
                Write-Host -NoNewline $editor.Render()
                
                # Check if console input is available (prevents crash in non-interactive mode)
                try {
                    if (-not [Console]::KeyAvailable) {
                        Start-Sleep -Milliseconds 50
                        continue
                    }
                    $key = [Console]::ReadKey($true)
                } catch {
                    # Console not available or error reading key
                    if ($global:Debug) { Write-Host "Console read error: $_" -ForegroundColor Red }
                    break
                }
                
                if (-not $editor.HandleInput($key)) {
                    # Editor finished
                    if ($key.Key -eq [System.ConsoleKey]::Enter) {
                        # Save tags
                        $task.Tags = $editor.GetTags()
                        $this.TaskService.UpdateTask($task)
                        $this.LoadTasks()
                    }
                    # Escape or Enter - exit without saving on Escape
                    break
                }
            }
        } catch {
            if ($global:Debug) { Write-Host "EditTaskTags error: $_" -ForegroundColor Red }
        } finally {
            [Console]::CursorVisible = $originalCursor
        }
        
        return $true
    }
    
    [bool] EditTagsFallback([SimpleTask]$task) {
        # Simple fallback for non-interactive environments
        Write-Host ""
        Write-Host "Current tags: $($task.Tags -join ', ')" -ForegroundColor Yellow
        Write-Host "Enter new tags (format: #tag1 #tag2 #tag3):" -NoNewline
        try {
            $input = Read-Host
            if ($input) {
                # Parse tags from input
                $tagParts = $input -split '#' | Where-Object { $_.Trim() -ne "" }
                $cleanTags = @()
                foreach ($part in $tagParts) {
                    $cleanTag = $part.Trim() -replace '\s+', '-'
                    if ($cleanTag -ne "") {
                        $cleanTags += $cleanTag
                    }
                }
                $task.Tags = $cleanTags
                $this.TaskService.UpdateTask($task)
                $this.LoadTasks()
                Write-Host "Tags updated: $($task.Tags -join ', ')" -ForegroundColor Green
            }
        } catch {
            if ($global:Debug) { Write-Host "Fallback tag editor error: $_" -ForegroundColor Red }
        }
        return $true
    }
    
    [void] CreateNewTask() {
        [Console]::SetCursorPosition(0, $this.Height)
        Write-Host -NoNewline "New task title: "
        [Console]::CursorVisible = $true
        $title = Read-Host
        [Console]::CursorVisible = $false
        
        if ($title) {
            $task = [SimpleTask]::new($title)
            $this.TaskService.AddTask($task)
            $this.LoadTasks()
        }
    }
    
    [void] CreateSubtask() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $parentTask = if ($item.Task.IsParent()) { $item.Task } else { $this.TaskService.GetTask($item.Task.ParentId) }
        
        if (-not $parentTask) { return }
        
        [Console]::SetCursorPosition(0, $this.Height)
        Write-Host -NoNewline "New subtask for '$($parentTask.Title)': "
        [Console]::CursorVisible = $true
        $title = Read-Host
        [Console]::CursorVisible = $false
        
        if ($title) {
            $subtask = [SimpleTask]::new($title)
            $this.TaskService.AddSubtask($parentTask.Id, $subtask)
            $this.LoadTasks()
        }
    }
    
    [void] DeleteTask() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        
        [Console]::SetCursorPosition(0, $this.Height)
        Write-Host -NoNewline "Delete '$($item.Task.Title)'? (y/N): "
        $confirm = [Console]::ReadKey($true)
        
        if ($confirm.KeyChar -eq 'y' -or $confirm.KeyChar -eq 'Y') {
            $this.TaskService.DeleteTask($item.Task.Id)
            $this.LoadTasks()
        }
    }
}
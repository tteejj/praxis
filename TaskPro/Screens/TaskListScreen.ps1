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
    
    # Inline editing state
    [int]$EditingIndex = -1
    [string]$EditingField = ""  # "title", "priority", "date", "tags"
    [string]$EditingValue = ""
    [SimpleTask]$EditingTask = $null
    [bool]$IsNewTask = $false
    
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
    [string]$EditHighlight = "`e[48;2;255;255;255;38;2;0;0;0m"  # White background, black text
    
    # Column widths for new layout (with proper spacing)
    [int]$StatusCol = 3      # "☐  "
    [int]$PriorityCol = 5    # "High "
    [int]$DateCol = 12       # "yyyy-mm-dd "
    [int]$ArrowCol = 3       # "▼  "
    [int]$IndentWidth = 4    # "    " for subtasks
    
    # Pillbox characters
    [string]$PillboxTopLeft = "╭"
    [string]$PillboxTopRight = "╮"
    [string]$PillboxBottomLeft = "╰"
    [string]$PillboxBottomRight = "╯"
    [string]$PillboxHorizontal = "─"
    [string]$PillboxVertical = "│"
    
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
    
    [int] GetItemHeight([int]$itemIndex) {
        # Selected item gets pillbox (5 lines: spacer + top + content + content + bottom)
        # Normal item gets 2 lines
        if ($itemIndex -eq $this.SelectedIndex) {
            return 5
        } else {
            return 2
        }
    }
    
    [int] CalculatePillboxWidth([SimpleTask]$task, [int]$level) {
        # Calculate minimum width needed for content
        $line1Length = $this.GetContentLength($task, $level)
        
        # Calculate tag line length
        $line2Length = 0
        if ($task.Tags.Count -gt 0) {
            $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
            if ($level -eq 1) {
                $indentSize += 7  # "    └─ "
            }
            $line2Length = $indentSize + 1 + ($task.Tags -join ", ").Length + 1  # "⟨tags⟩"
        }
        
        # Use the longer of the two lines, plus borders and padding  
        $contentWidth = [Math]::Max($line1Length, $line2Length)
        $pillboxWidth = $contentWidth + 4  # "│" + " " + content + "│"
        
        # Ensure minimum width and don't exceed screen
        $minWidth = 40
        $maxWidth = $this.Width - 4
        
        return [Math]::Min($maxWidth, [Math]::Max($minWidth, $pillboxWidth))
    }
    
    [void] RenderPillboxTop([System.Text.StringBuilder]$sb, [int]$width, [int]$y) {
        [void]$sb.Append([VT]::MoveTo(0, $y))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append($this.PillboxTopLeft)
        [void]$sb.Append($this.PillboxHorizontal * ($width - 2))
        [void]$sb.Append($this.PillboxTopRight)
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] RenderPillboxBottom([System.Text.StringBuilder]$sb, [int]$width, [int]$y) {
        [void]$sb.Append([VT]::MoveTo(0, $y))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append($this.PillboxBottomLeft)
        [void]$sb.Append($this.PillboxHorizontal * ($width - 2))
        [void]$sb.Append($this.PillboxBottomRight)
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] RenderPillboxSide([System.Text.StringBuilder]$sb, [int]$x, [int]$y) {
        [void]$sb.Append([VT]::MoveTo($x, $y))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append($this.PillboxVertical)
        [void]$sb.Append($this.NormalColor)
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
        if ($this.EditingIndex -ge 0) {
            [void]$sb.Append("EDITING [$($this.EditingField.ToUpper())]: Tab:Next Field  Enter:Save  Escape:Cancel")
        } else {
            [void]$sb.Append("↑↓:Navigate  E:Edit  A:Add  N:New  S:Subtask  X:Toggle  Enter:Notes  T:Theme  R:Tags  Q:Quit")
        }
        [void]$sb.Append($this.NormalColor)
        
        # Show/hide cursor based on editing state and position it correctly
        if ($this.EditingIndex -ge 0) {
            [void]$sb.Append([VT]::ShowCursor())
            # Position cursor at the end of the editing field
            $this.PositionCursorForEditing($sb)
        } else {
            [void]$sb.Append([VT]::HideCursor())
        }
        
        return $sb.ToString()
    }
    
    [void] RenderTaskList([System.Text.StringBuilder]$sb) {
        $startY = 3
        $currentY = $startY
        $availableHeight = $this.Height - 5  # Header + status bar
        
        # Calculate how many items we can show with dynamic heights
        $visibleItems = @()
        $totalHeight = 0
        
        for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count; $i++) {
            $itemHeight = $this.GetItemHeight($i)
            if ($totalHeight + $itemHeight -le $availableHeight) {
                $visibleItems += $i
                $totalHeight += $itemHeight
            } else {
                break
            }
        }
        
        # Render each visible item
        foreach ($i in $visibleItems) {
            $item = $this.FlatList[$i]
            $task = $item.Task
            $level = $item.Level
            $isLast = $item.IsLast
            $isSelected = ($i -eq $this.SelectedIndex)
            
            if ($isSelected) {
                # === SELECTED ITEM WITH PILLBOX ===
                
                # Calculate optimal pillbox width
                $pillboxWidth = $this.CalculatePillboxWidth($task, $level)
                
                # CRITICAL: Calculate the fixed right border position for BOTH lines
                $rightBorderColumn = $pillboxWidth
                
                # Spacer line above
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append(" " * $this.Width)
                $currentY++
                
                # Pillbox top
                $this.RenderPillboxTop($sb, $pillboxWidth, $currentY)
                $currentY++
                
                # Content line 1 with pillbox sides
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                $this.RenderTaskContent($sb, $task, $level, $isLast, $false)
                
                # Move cursor to EXACT right border position
                [void]$sb.Append([VT]::MoveTo($rightBorderColumn, $currentY))
                [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                $currentY++
                
                # Content line 2 (tags) with pillbox sides
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                
                # Render tag content
                $isEditingThis = ($this.EditingTask -and $this.EditingTask.Id -eq $task.Id)
                if ($isEditingThis -and $this.EditingField -eq "tags") {
                    # Show editing highlight for tags
                    $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                    if ($level -eq 1) {
                        $indentSize += 7  # "    └─ "
                    }
                    [void]$sb.Append(" " * $indentSize)
                    [void]$sb.Append($this.EditHighlight + "⟨" + $this.EditingValue + "⟩" + $this.NormalColor)
                } elseif ($task.Tags.Count -gt 0) {
                    # Normal tag display
                    $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                    if ($level -eq 1) {
                        $indentSize += 7  # "    └─ "
                    }
                    [void]$sb.Append(" " * $indentSize)
                    [void]$sb.Append($this.TagColor + "⟨" + ($task.Tags -join ", ") + "⟩" + $this.NormalColor)
                } elseif ($isEditingThis -and $this.EditingField -eq "tags") {
                    # Show empty tags field when editing
                    $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                    if ($level -eq 1) {
                        $indentSize += 7  # "    └─ "
                    }
                    [void]$sb.Append(" " * $indentSize)
                    [void]$sb.Append($this.EditHighlight + "⟨" + $this.EditingValue + "⟩" + $this.NormalColor)
                }
                
                # Move cursor to EXACT same right border position
                [void]$sb.Append([VT]::MoveTo($rightBorderColumn, $currentY))
                [void]$sb.Append($this.HeaderColor + $this.PillboxVertical + $this.NormalColor)
                $currentY++
                
                # Pillbox bottom
                $this.RenderPillboxBottom($sb, $pillboxWidth, $currentY)
                $currentY++
                
            } else {
                # === NORMAL ITEM (2 lines) ===
                
                # Content line 1
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $this.RenderTaskContent($sb, $task, $level, $isLast, $true)
                $currentY++
                
                # Content line 2 (tags)
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $this.RenderTagContent($sb, $task, $level)
                [void]$sb.Append([VT]::ClearLine())
                $currentY++
            }
        }
        
        # Clear remaining lines properly
        while ($currentY -lt ($this.Height - 2)) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append([VT]::ClearLine())
            $currentY++
        }
    }
    
    [void] RenderTaskContent([System.Text.StringBuilder]$sb, [SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$clearToEnd) {
        $isEditingThis = ($this.EditingTask -and $this.EditingTask.Id -eq $task.Id)
        
        # COLUMN 1: STATUS (3 chars) - ☐ or ■
        if ($isEditingThis -and $this.EditingField -eq "status") {
            [void]$sb.Append($this.EditHighlight + $this.EditingValue.PadRight(3) + $this.NormalColor)
        } else {
            if ($task.Completed) {
                [void]$sb.Append("■  ")  # Filled square for completed
            } else {
                [void]$sb.Append("☐  ")  # Open square for incomplete
            }
        }
        
        # COLUMN 2: PRIORITY (5 chars)
        if ($level -eq 0) {
            if ($isEditingThis -and $this.EditingField -eq "priority") {
                [void]$sb.Append($this.EditHighlight + $this.EditingValue.PadRight(5) + $this.NormalColor)
            } else {
                $priorityText = switch ($task.Priority) {
                    "High" { "High " }
                    "Medium" { "Med  " }
                    "Low" { "Low  " }
                    default { "     " }
                }
                $priorityColor = switch ($task.Priority) {
                    "High" { $this.HighColor }
                    "Medium" { $this.MediumColor }
                    "Low" { $this.LowColor }
                    default { $this.TagColor }
                }
                [void]$sb.Append($priorityColor + $priorityText + $this.NormalColor)
            }
        } else {
            [void]$sb.Append("     ")  # Empty for subtasks
        }
        
        # COLUMN 3: DATE (12 chars with color)
        if ($level -eq 0) {
            if ($isEditingThis -and $this.EditingField -eq "date") {
                [void]$sb.Append($this.EditHighlight + $this.EditingValue.PadRight(11) + $this.NormalColor + " ")
            } else {
                [void]$sb.Append($this.GetDateColorAndText($task))
                [void]$sb.Append(" ")
            }
        } else {
            [void]$sb.Append(" " * $this.DateCol)
        }
        
        # COLUMN 4: ARROW (3 chars - closest to task)
        if ($level -eq 0 -and $task.Subtasks.Count -gt 0) {
            if ($this.GlobalCollapseSubtasks -or $task.SubtasksCollapsed) {
                [void]$sb.Append("▶  ")  # Collapsed
            } else {
                [void]$sb.Append("▼  ")  # Expanded
            }
        } else {
            [void]$sb.Append("   ")
        }
        
        # COLUMN 5: TITLE (with indentation for subtasks)
        if ($level -eq 1) {
            if ($isLast) {
                [void]$sb.Append("    └─ ")
            } else {
                [void]$sb.Append("    ├─ ")
            }
        }
        
        # Task title color and content
        if ($isEditingThis -and $this.EditingField -eq "title") {
            [void]$sb.Append($this.EditHighlight + $this.EditingValue + $this.NormalColor)
        } else {
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
            
            [void]$sb.Append($taskColor + $task.Title + $this.NormalColor)
        }
        
        # Clear to end of line if requested
        if ($clearToEnd) {
            $contentLength = $this.GetContentLength($task, $level)
            $padding = $this.Width - $contentLength
            [void]$sb.Append(" " * [Math]::Max(0, $padding))
        }
    }
    
    [void] RenderTagContent([System.Text.StringBuilder]$sb, [SimpleTask]$task, [int]$level) {
        if ($task.Tags.Count -gt 0) {
            # Indent to align with title
            $indentSize = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
            if ($level -eq 1) {
                $indentSize += 7  # "    └─ "
            }
            [void]$sb.Append(" " * $indentSize)
            
            # Tags in angle brackets
            [void]$sb.Append($this.TagColor)
            [void]$sb.Append("⟨" + ($task.Tags -join ", ") + "⟩")
            [void]$sb.Append($this.NormalColor)
        }
    }
    
    [int] GetContentLength([SimpleTask]$task, [int]$level) {
        $length = $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
        if ($level -eq 1) {
            $length += 7  # "    └─ "
        }
        $length += $task.Title.Length
        return $length
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle editing mode input first
        if ($this.EditingIndex -ge 0) {
            return $this.HandleEditingInput($key)
        }
        
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
                # Start inline add new task (same as A key)
                $this.StartInlineAdd()
                return $true
            }
            ([System.ConsoleKey]::S) {
                # Start inline subtask creation
                if ($this.FlatList.Count -gt 0) {
                    $this.StartInlineSubtask()
                }
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
            ([System.ConsoleKey]::E) {
                # Start inline editing of current task
                if ($this.FlatList.Count -gt 0) {
                    $this.StartInlineEdit()
                }
                return $true
            }
            ([System.ConsoleKey]::A) {
                # Start inline add new task
                $this.StartInlineAdd()
                return $true
            }
            ([System.ConsoleKey]::Q) {
                return $false
            }
        }
        
        return $true
    }
    
    [void] EnsureVisible() {
        # Ensure selected item is visible with dynamic heights
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        } else {
            # Check if selected item fits in current view
            $availableHeight = $this.Height - 5
            $totalHeight = 0
            $needsScroll = $true
            
            for ($i = $this.ScrollTop; $i -le $this.SelectedIndex -and $i -lt $this.FlatList.Count; $i++) {
                $itemHeight = $this.GetItemHeight($i)
                $totalHeight += $itemHeight
                
                if ($i -eq $this.SelectedIndex) {
                    if ($totalHeight -le $availableHeight) {
                        $needsScroll = $false
                    }
                    break
                }
            }
            
            if ($needsScroll) {
                # Scroll to show selected item
                $this.ScrollTop = [Math]::Max(0, $this.SelectedIndex - 1)
            }
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
    
    # === INLINE EDITING METHODS ===
    
    [void] StartInlineEdit() {
        $item = $this.FlatList[$this.SelectedIndex]
        $this.EditingIndex = $this.SelectedIndex
        $this.EditingTask = $item.Task
        $this.EditingField = "priority"  # Start with priority (leftmost)
        $this.EditingValue = $item.Task.Priority
        $this.IsNewTask = $false
    }
    
    [void] StartInlineAdd() {
        # Create a new task and add it temporarily to the end
        $newTask = [SimpleTask]::new("")
        $this.FlatList.Add(@{
            Task = $newTask
            Level = 0
            IsLast = $false
        })
        $this.EditingIndex = $this.FlatList.Count - 1
        $this.EditingTask = $newTask
        $this.EditingField = "priority"  # Start with priority (leftmost)
        $this.EditingValue = ""
        $this.SelectedIndex = $this.EditingIndex
        $this.IsNewTask = $true
        $this.EnsureVisible()
    }
    
    [void] StartInlineSubtask() {
        $item = $this.FlatList[$this.SelectedIndex]
        $parentTask = if ($item.Task.IsParent()) { $item.Task } else { $this.TaskService.GetTask($item.Task.ParentId) }
        
        if (-not $parentTask) { return }
        
        # Create a new subtask and add it after the parent's subtasks
        $newSubtask = [SimpleTask]::new("")
        
        # Find the position to insert (after last subtask of this parent)
        $insertIndex = $this.SelectedIndex + 1
        for ($i = $this.SelectedIndex + 1; $i -lt $this.FlatList.Count; $i++) {
            $nextItem = $this.FlatList[$i]
            if ($nextItem.Level -eq 1 -and $this.TaskService.GetParentTask($nextItem.Task.Id).Id -eq $parentTask.Id) {
                $insertIndex = $i + 1
            } else {
                break
            }
        }
        
        $this.FlatList.Insert($insertIndex, @{
            Task = $newSubtask
            Level = 1
            IsLast = $false
        })
        
        $this.EditingIndex = $insertIndex
        $this.EditingTask = $newSubtask
        $this.EditingField = "priority"  # Start with priority (leftmost)
        $this.EditingValue = ""
        $this.SelectedIndex = $this.EditingIndex
        $this.IsNewTask = $true
        $this.EnsureVisible()
    }
    
    [bool] HandleEditingInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                # For new tasks, only save after completing all fields
                if ($this.IsNewTask) {
                    if ($this.EditingField -eq "tags") {
                        $this.SaveInlineEdit()
                    } else {
                        $this.NextEditField()
                    }
                } else {
                    # For existing tasks, save immediately
                    $this.SaveInlineEdit()
                }
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                # Cancel editing
                $this.CancelInlineEdit()
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                # Check for Shift+Tab (reverse)
                if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    $this.PreviousEditField()
                } else {
                    $this.NextEditField()
                }
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.EditingValue.Length -gt 0) {
                    $this.EditingValue = $this.EditingValue.Substring(0, $this.EditingValue.Length - 1)
                }
                return $true
            }
            default {
                # Add character to editing value
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    $this.EditingValue += $key.KeyChar
                }
                return $true
            }
        }
        return $true
    }
    
    [void] NextEditField() {
        # Cycle through fields: priority -> date -> title -> tags -> save (for new) or priority (for existing)
        switch ($this.EditingField) {
            "priority" {
                $this.EditingTask.Priority = $this.EditingValue
                $this.EditingField = "date"
                if ($this.EditingTask.DueDate -eq [datetime]::MinValue) {
                    $this.EditingValue = ""
                } else {
                    $this.EditingValue = $this.EditingTask.DueDate.ToString("yyyy-MM-dd")
                }
            }
            "date" {
                if ($this.EditingValue) {
                    try {
                        $this.EditingTask.DueDate = [datetime]::Parse($this.EditingValue)
                    } catch {
                        # Invalid date, keep current
                    }
                }
                $this.EditingField = "title"
                $this.EditingValue = $this.EditingTask.Title
            }
            "title" {
                $this.EditingTask.Title = $this.EditingValue
                $this.EditingField = "tags"
                $this.EditingValue = ($this.EditingTask.Tags -join ", ")
            }
            "tags" {
                # Parse tags from input
                if ($this.EditingValue) {
                    $tagParts = $this.EditingValue -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    $this.EditingTask.Tags = $tagParts
                } else {
                    $this.EditingTask.Tags = @()
                }
                
                if ($this.IsNewTask) {
                    # For new tasks, we're done - will save on next Enter
                    return
                } else {
                    # For existing tasks, cycle back to priority
                    $this.EditingField = "priority"
                    $this.EditingValue = $this.EditingTask.Priority
                }
            }
        }
    }
    
    [void] PreviousEditField() {
        # Cycle backwards: priority <- date <- title <- tags
        switch ($this.EditingField) {
            "priority" {
                $this.EditingTask.Priority = $this.EditingValue
                $this.EditingField = "tags"
                $this.EditingValue = ($this.EditingTask.Tags -join ", ")
            }
            "date" {
                if ($this.EditingValue) {
                    try {
                        $this.EditingTask.DueDate = [datetime]::Parse($this.EditingValue)
                    } catch {
                        # Invalid date, keep current
                    }
                }
                $this.EditingField = "priority"
                $this.EditingValue = $this.EditingTask.Priority
            }
            "title" {
                $this.EditingTask.Title = $this.EditingValue
                $this.EditingField = "date"
                if ($this.EditingTask.DueDate -eq [datetime]::MinValue) {
                    $this.EditingValue = ""
                } else {
                    $this.EditingValue = $this.EditingTask.DueDate.ToString("yyyy-MM-dd")
                }
            }
            "tags" {
                # Parse tags from input
                if ($this.EditingValue) {
                    $tagParts = $this.EditingValue -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    $this.EditingTask.Tags = $tagParts
                } else {
                    $this.EditingTask.Tags = @()
                }
                $this.EditingField = "title"
                $this.EditingValue = $this.EditingTask.Title
            }
        }
    }
    
    [void] SaveInlineEdit() {
        # Apply final field value
        switch ($this.EditingField) {
            "title" { $this.EditingTask.Title = $this.EditingValue }
            "priority" { $this.EditingTask.Priority = $this.EditingValue }
            "date" {
                if ($this.EditingValue) {
                    try {
                        $this.EditingTask.DueDate = [datetime]::Parse($this.EditingValue)
                    } catch {
                        # Invalid date, keep current
                    }
                }
            }
            "tags" {
                # Parse tags from input
                if ($this.EditingValue) {
                    $tagParts = $this.EditingValue -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    $this.EditingTask.Tags = $tagParts
                } else {
                    $this.EditingTask.Tags = @()
                }
            }
        }
        
        # Save to service
        if ($this.EditingTask.Title) {
            if ($this.EditingTask.Id -eq [guid]::Empty) {
                # New task - check if it's a subtask
                $item = $this.FlatList[$this.EditingIndex]
                if ($item.Level -eq 1) {
                    # Find parent task
                    for ($i = $this.EditingIndex - 1; $i -ge 0; $i--) {
                        $parentItem = $this.FlatList[$i]
                        if ($parentItem.Level -eq 0) {
                            $this.TaskService.AddSubtask($parentItem.Task.Id, $this.EditingTask)
                            break
                        }
                    }
                } else {
                    # Regular parent task
                    $this.TaskService.AddTask($this.EditingTask)
                }
            } else {
                # Existing task
                $this.TaskService.UpdateTask($this.EditingTask)
            }
        } else {
            # Empty title, remove if it was a new task
            if ($this.EditingTask.Id -eq [guid]::Empty) {
                $this.FlatList.RemoveAt($this.EditingIndex)
            }
        }
        
        $this.EndInlineEdit()
    }
    
    [void] CancelInlineEdit() {
        # Remove new task if it was being added
        if ($this.EditingTask.Id -eq [guid]::Empty) {
            $this.FlatList.RemoveAt($this.EditingIndex)
            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
            }
        }
        $this.EndInlineEdit()
    }
    
    [void] EndInlineEdit() {
        $this.EditingIndex = -1
        $this.EditingField = ""
        $this.EditingValue = ""
        $this.EditingTask = $null
        $this.IsNewTask = $false
        $this.LoadTasks()  # Refresh the list
    }
    
    [void] PositionCursorForEditing([System.Text.StringBuilder]$sb) {
        if ($this.EditingIndex -lt 0) { return }
        
        # Calculate the position of the editing field
        $item = $this.FlatList[$this.EditingIndex]
        $level = $item.Level
        
        # Find the Y position of the editing item
        $startY = 3
        $currentY = $startY
        $foundY = -1
        
        # Calculate how many items we can show with dynamic heights
        for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count; $i++) {
            $itemHeight = $this.GetItemHeight($i)
            if ($i -eq $this.EditingIndex) {
                # Found our editing item, it will be in pillbox mode (5 lines)
                if ($this.EditingField -eq "tags") {
                    $foundY = $currentY + 3  # Tag line is 3rd line of pillbox
                } else {
                    $foundY = $currentY + 2  # Content line is 2nd line of pillbox
                }
                break
            }
            $currentY += $itemHeight
            if ($currentY -ge ($this.Height - 5)) { break }
        }
        
        if ($foundY -ge 0) {
            # Calculate X position based on field being edited
            $x = 1  # Start after the left border "│"
            
            switch ($this.EditingField) {
                "status" {
                    $x += $this.EditingValue.Length
                }
                "priority" {
                    $x += $this.StatusCol + $this.EditingValue.Length
                }
                "date" {
                    $x += $this.StatusCol + $this.PriorityCol + $this.EditingValue.Length
                }
                "title" {
                    $x += $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                    if ($level -eq 1) {
                        $x += 7  # "    └─ "
                    }
                    $x += $this.EditingValue.Length
                }
                "tags" {
                    $x += $this.StatusCol + $this.PriorityCol + $this.DateCol + $this.ArrowCol
                    if ($level -eq 1) {
                        $x += 7  # "    └─ "
                    }
                    $x += 1 + $this.EditingValue.Length  # "⟨" + content
                }
            }
            
            [void]$sb.Append([VT]::MoveTo($x, $foundY))
        }
    }
}
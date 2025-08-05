# TaskScreen.ps1 - Main task management screen with editor

class TaskScreen {
    [TaskService]$TaskService
    [Task[]]$Tasks
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [TextEditor]$Editor
    [Task]$CurrentTask
    [bool]$EditorFocused = $false
    
    # Layout
    [int]$Width
    [int]$Height
    [int]$ListWidth = 40
    [int]$EditorX
    [int]$EditorWidth
    
    # Colors
    [string]$BorderColor = "`e[90m"     # Dark gray
    [string]$HeaderColor = "`e[96m"     # Cyan
    [string]$SelectedColor = "`e[7m"    # Reverse
    [string]$NormalColor = "`e[0m"      # Reset
    
    TaskScreen() {
        $this.TaskService = [TaskService]::new()
        $this.Editor = [TextEditor]::new()
        $this.LoadTasks()
    }
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        $this.EditorX = $this.ListWidth
        $this.EditorWidth = $width - $this.ListWidth
        
        # Set editor bounds (leave room for header and borders)
        $this.Editor.SetBounds($this.EditorX + 1, 4, $this.EditorWidth - 2, $height - 6)
        
        if ($this.Tasks.Count -gt 0) {
            $this.SelectTask(0)
        }
    }
    
    [void] LoadTasks() {
        $this.Tasks = $this.TaskService.GetActiveTasks()
        if ($this.SelectedIndex -ge $this.Tasks.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.Tasks.Count - 1)
        }
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen
        [void]$sb.Append([VT]::Clear())
        
        # Draw borders
        $this.DrawBorders($sb)
        
        # Draw task list
        $this.DrawTaskList($sb)
        
        # Draw editor panel
        $this.DrawEditorPanel($sb)
        
        # Draw status bar
        $this.DrawStatusBar($sb)
        
        # Editor content
        if ($this.CurrentTask) {
            [void]$sb.Append($this.Editor.Render())
        }
        
        # Position cursor
        if ($this.EditorFocused) {
            # Cursor will be positioned by editor
        } else {
            [void]$sb.Append([VT]::HideCursor())
        }
        
        return $sb.ToString()
    }
    
    [void] DrawBorders([System.Text.StringBuilder]$sb) {
        [void]$sb.Append($this.BorderColor)
        
        # Top border
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append("┌" + ("─" * ($this.ListWidth - 2)) + "┬" + ("─" * ($this.EditorWidth - 2)) + "┐")
        
        # Middle separator
        for ($y = 1; $y -lt $this.Height - 1; $y++) {
            [void]$sb.Append([VT]::MoveTo($this.ListWidth - 1, $y))
            [void]$sb.Append("│")
        }
        
        # Bottom border
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
        [void]$sb.Append("└" + ("─" * ($this.ListWidth - 2)) + "┴" + ("─" * ($this.EditorWidth - 2)) + "┘")
        
        # Side borders
        for ($y = 1; $y -lt $this.Height - 1; $y++) {
            [void]$sb.Append([VT]::MoveTo(0, $y))
            [void]$sb.Append("│")
            [void]$sb.Append([VT]::MoveTo($this.Width - 1, $y))
            [void]$sb.Append("│")
        }
        
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] DrawTaskList([System.Text.StringBuilder]$sb) {
        # Header
        [void]$sb.Append([VT]::MoveTo(2, 1))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append("TASKS")
        [void]$sb.Append($this.NormalColor)
        
        # Task list
        $listHeight = $this.Height - 4  # Account for borders and header
        $visibleTasks = [Math]::Min($listHeight, $this.Tasks.Count - $this.ScrollTop)
        
        for ($i = 0; $i -lt $listHeight; $i++) {
            $taskIndex = $this.ScrollTop + $i
            [void]$sb.Append([VT]::MoveTo(2, $i + 2))  # Start at column 2 to avoid border
            
            if ($taskIndex -lt $this.Tasks.Count) {
                $task = $this.Tasks[$taskIndex]
                $isSelected = ($taskIndex -eq $this.SelectedIndex)
                
                # Selection highlight
                if ($isSelected -and -not $this.EditorFocused) {
                    [void]$sb.Append($this.SelectedColor)
                }
                
                # Status icon
                [void]$sb.Append(" ")
                [void]$sb.Append($task.GetStatusIcon())
                [void]$sb.Append(" ")
                
                # Priority color
                if (-not $isSelected -or $this.EditorFocused) {
                    [void]$sb.Append($task.GetPriorityColor())
                }
                
                # Title (truncate if needed)
                $titleWidth = $this.ListWidth - 15  # Leave room for status, due date, and border
                $title = $task.Title
                if ($title.Length -gt $titleWidth) {
                    $title = $title.Substring(0, $titleWidth - 1) + "…"
                }
                [void]$sb.Append($title.PadRight($titleWidth))
                
                # Due date
                [void]$sb.Append(" ")
                [void]$sb.Append($task.GetDueDateDisplay())
                
                [void]$sb.Append($this.NormalColor)
            } else {
                [void]$sb.Append(" " * ($this.ListWidth - 4))  # Account for border and padding
            }
        }
    }
    
    [void] DrawEditorPanel([System.Text.StringBuilder]$sb) {
        if ($this.CurrentTask) {
            # Header with task details
            [void]$sb.Append([VT]::MoveTo($this.EditorX + 2, 1))
            [void]$sb.Append($this.HeaderColor)
            [void]$sb.Append("TASK DETAILS")
            [void]$sb.Append($this.NormalColor)
            
            # Task info
            [void]$sb.Append([VT]::MoveTo($this.EditorX + 2, 2))
            [void]$sb.Append("Title: ")
            [void]$sb.Append("`e[93m")  # Yellow
            [void]$sb.Append($this.CurrentTask.Title)
            [void]$sb.Append($this.NormalColor)
            
            # Separator
            [void]$sb.Append([VT]::MoveTo($this.EditorX + 1, 3))
            [void]$sb.Append($this.BorderColor)
            [void]$sb.Append("─" * ($this.EditorWidth - 2))
            [void]$sb.Append($this.NormalColor)
        } else {
            [void]$sb.Append([VT]::MoveTo($this.EditorX + 2, $this.Height / 2))
            [void]$sb.Append("`e[90m")  # Dark gray
            [void]$sb.Append("No task selected")
            [void]$sb.Append($this.NormalColor)
        }
    }
    
    [void] DrawStatusBar([System.Text.StringBuilder]$sb) {
        # Draw separator line above status
        [void]$sb.Append([VT]::MoveTo(1, $this.Height - 2))
        [void]$sb.Append($this.BorderColor)
        [void]$sb.Append("├" + ("─" * ($this.ListWidth - 2)) + "┼" + ("─" * ($this.EditorWidth - 2)) + "┤")
        [void]$sb.Append($this.NormalColor)
        
        # Status text
        [void]$sb.Append([VT]::MoveTo(2, $this.Height - 1))
        
        if ($this.EditorFocused) {
            [void]$sb.Append("Tab:List  ^S:Save  ^Z:Undo  ^Y:Redo")
        } else {
            [void]$sb.Append("↑↓:Navigate  Space:Complete  N:New  E:Edit  D:Delete  Tab:Editor  Q:Quit")
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($this.EditorFocused) {
            # Editor handles most keys
            if ($key.Key -eq [System.ConsoleKey]::Tab) {
                $this.EditorFocused = $false
                return $true
            }
            
            if ($key.Key -eq [System.ConsoleKey]::S -and 
                ($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
                $this.SaveCurrentTask()
                return $true
            }
            
            return $this.Editor.HandleInput($key)
        } else {
            # List navigation
            switch ($key.Key) {
                ([System.ConsoleKey]::UpArrow) {
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectTask($this.SelectedIndex - 1)
                    }
                    return $true
                }
                ([System.ConsoleKey]::DownArrow) {
                    if ($this.SelectedIndex -lt ($this.Tasks.Count - 1)) {
                        $this.SelectTask($this.SelectedIndex + 1)
                    }
                    return $true
                }
                ([System.ConsoleKey]::Spacebar) {
                    if ($this.CurrentTask) {
                        $this.TaskService.ToggleComplete($this.CurrentTask.Id)
                        $this.LoadTasks()
                        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Tasks.Count) {
                            $this.SelectTask($this.SelectedIndex)
                        }
                    }
                    return $true
                }
                ([System.ConsoleKey]::Tab) {
                    if ($this.CurrentTask) {
                        $this.EditorFocused = $true
                    }
                    return $true
                }
                ([System.ConsoleKey]::N) {
                    $this.CreateNewTask()
                    return $true
                }
                ([System.ConsoleKey]::E) {
                    if ($this.CurrentTask) {
                        $this.EditorFocused = $true
                    }
                    return $true
                }
                ([System.ConsoleKey]::D) {
                    if ($this.CurrentTask) {
                        $this.DeleteCurrentTask()
                    }
                    return $true
                }
                ([System.ConsoleKey]::Q) {
                    return $false
                }
            }
        }
        
        return $true
    }
    
    [void] SelectTask([int]$index) {
        $this.SelectedIndex = $index
        
        # Update scroll position
        $listHeight = $this.Height - 4
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollTop + $listHeight)) {
            $this.ScrollTop = $this.SelectedIndex - $listHeight + 1
        }
        
        # Load task into editor
        if ($index -ge 0 -and $index -lt $this.Tasks.Count) {
            $this.CurrentTask = $this.Tasks[$index]
            $this.Editor.SetText($this.CurrentTask.Notes)
        }
    }
    
    [void] SaveCurrentTask() {
        if ($this.CurrentTask -and $this.Editor.Modified) {
            $this.CurrentTask.Notes = $this.Editor.GetText()
            $this.TaskService.UpdateTask($this.CurrentTask)
            $this.Editor.Modified = $false
        }
    }
    
    [void] CreateNewTask() {
        # Simple prompt for new task
        [void][Console]::SetCursorPosition(2, $this.Height)
        Write-Host -NoNewline "New task title: "
        [Console]::CursorVisible = $true
        $title = Read-Host
        [Console]::CursorVisible = $false
        
        if ($title) {
            $task = [Task]::new($title)
            $this.TaskService.AddTask($task)
            $this.LoadTasks()
            
            # Select the new task
            for ($i = 0; $i -lt $this.Tasks.Count; $i++) {
                if ($this.Tasks[$i].Id -eq $task.Id) {
                    $this.SelectTask($i)
                    break
                }
            }
        }
    }
    
    [void] DeleteCurrentTask() {
        if ($this.CurrentTask) {
            # Simple confirmation
            [void][Console]::SetCursorPosition(2, $this.Height)
            Write-Host -NoNewline "Delete task? (y/N): "
            $confirm = [Console]::ReadKey($true)
            
            if ($confirm.KeyChar -eq 'y' -or $confirm.KeyChar -eq 'Y') {
                $this.TaskService.DeleteTask($this.CurrentTask.Id)
                $this.LoadTasks()
                
                if ($this.Tasks.Count -gt 0) {
                    $this.SelectTask([Math]::Min($this.SelectedIndex, $this.Tasks.Count - 1))
                } else {
                    $this.CurrentTask = $null
                    $this.Editor.SetText("")
                }
            }
        }
    }
}
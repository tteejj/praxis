# EditTaskDialog.ps1 - Dialog for editing existing tasks

class EditTaskDialog : Screen {
    [Task]$Task
    [TextBox]$TitleBox
    [TextBox]$DescriptionBox
    [ListBox]$StatusList
    [ListBox]$PriorityList
    [TextBox]$ProgressBox
    [Button]$SaveButton
    [Button]$CancelButton
    [scriptblock]$OnSave = {}
    [scriptblock]$OnCancel = {}
    
    EditTaskDialog([Task]$task) : base() {
        $this.Title = "Edit Task"
        $this.Task = $task
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        # Create title textbox
        $this.TitleBox = [TextBox]::new()
        $this.TitleBox.Text = $this.Task.Title
        $this.TitleBox.Placeholder = "Enter task title..."
        $this.TitleBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.TitleBox)
        
        # Create description textbox
        $this.DescriptionBox = [TextBox]::new()
        $this.DescriptionBox.Text = $this.Task.Description
        $this.DescriptionBox.Placeholder = "Enter description (optional)..."
        $this.DescriptionBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.DescriptionBox)
        
        # Create status list
        $this.StatusList = [ListBox]::new()
        $this.StatusList.Title = "Status"
        $this.StatusList.ShowBorder = $true
        $this.StatusList.Initialize($global:ServiceContainer)
        $this.StatusList.SetItems(@(
            @{Name="Pending"; Value=[TaskStatus]::Pending},
            @{Name="In Progress"; Value=[TaskStatus]::InProgress},
            @{Name="Completed"; Value=[TaskStatus]::Completed},
            @{Name="Cancelled"; Value=[TaskStatus]::Cancelled}
        ))
        $this.StatusList.ItemRenderer = { param($item) $item.Name }
        # Select current status
        for ($i = 0; $i -lt $this.StatusList.Items.Count; $i++) {
            if ($this.StatusList.Items[$i].Value -eq $this.Task.Status) {
                $this.StatusList.SelectIndex($i)
                break
            }
        }
        $this.AddChild($this.StatusList)
        
        # Create priority list
        $this.PriorityList = [ListBox]::new()
        $this.PriorityList.Title = "Priority"
        $this.PriorityList.ShowBorder = $true
        $this.PriorityList.Initialize($global:ServiceContainer)
        $this.PriorityList.SetItems(@(
            @{Name="Low"; Value=[TaskPriority]::Low},
            @{Name="Medium"; Value=[TaskPriority]::Medium},
            @{Name="High"; Value=[TaskPriority]::High}
        ))
        $this.PriorityList.ItemRenderer = { param($item) $item.Name }
        # Select current priority
        for ($i = 0; $i -lt $this.PriorityList.Items.Count; $i++) {
            if ($this.PriorityList.Items[$i].Value -eq $this.Task.Priority) {
                $this.PriorityList.SelectIndex($i)
                break
            }
        }
        $this.AddChild($this.PriorityList)
        
        # Create progress textbox
        $this.ProgressBox = [TextBox]::new()
        $this.ProgressBox.Text = $this.Task.Progress.ToString()
        $this.ProgressBox.Placeholder = "0-100"
        $this.ProgressBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.ProgressBox)
        
        # Create buttons
        $this.SaveButton = [Button]::new("Save")
        # Capture dialog reference
        $dialog = $this
        $this.SaveButton.OnClick = {
            if ($dialog.TitleBox.Text.Trim()) {
                $selectedStatus = $dialog.StatusList.GetSelectedItem()
                $selectedPriority = $dialog.PriorityList.GetSelectedItem()
                $progress = 0
                if ([int]::TryParse($dialog.ProgressBox.Text, [ref]$progress)) {
                    $progress = [Math]::Max(0, [Math]::Min(100, $progress))
                }
                
                if ($dialog.OnSave) {
                    & $dialog.OnSave @{
                        Title = $dialog.TitleBox.Text
                        Description = $dialog.DescriptionBox.Text
                        Status = if ($selectedStatus) { $selectedStatus.Value } else { $dialog.Task.Status }
                        Priority = if ($selectedPriority) { $selectedPriority.Value } else { $dialog.Task.Priority }
                        Progress = $progress
                    }
                }
            }
        }.GetNewClosure()
        $this.SaveButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.SaveButton)
        
        $this.CancelButton = [Button]::new("Cancel")
        $this.CancelButton.OnClick = {
            if ($dialog.OnCancel) {
                & $dialog.OnCancel
            }
        }.GetNewClosure()
        $this.CancelButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.CancelButton)
        
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                if ($this.OnCancel) {
                    & $this.OnCancel
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $focused = $this.FindFocused()
                if ($focused -eq $this.SaveButton) {
                    & $this.SaveButton.OnClick
                } elseif ($focused -eq $this.CancelButton) {
                    & $this.CancelButton.OnClick
                }
                return $true
            }
        }
        
        # Let base class handle other keys (like Tab navigation)
        return ([Screen]$this).HandleInput($key)
    }
    
    [void] OnBoundsChanged() {
        # Dialog dimensions
        $dialogWidth = 65
        $dialogHeight = 22
        $centerX = [int](($this.Width - $dialogWidth) / 2)
        $centerY = [int](($this.Height - $dialogHeight) / 2)
        
        # Position components
        $this.TitleBox.SetBounds($centerX + 2, $centerY + 2, $dialogWidth - 4, 3)
        $this.DescriptionBox.SetBounds($centerX + 2, $centerY + 6, $dialogWidth - 4, 3)
        
        $this.StatusList.SetBounds($centerX + 2, $centerY + 10, 20, 6)
        $this.PriorityList.SetBounds($centerX + 24, $centerY + 10, 20, 5)
        $this.ProgressBox.SetBounds($centerX + 46, $centerY + 10, 16, 3)
        
        # Position buttons (use similar logic to ProjectsScreen)
        $buttonY = $centerY + 17
        $buttonHeight = 3
        $buttonSpacing = 2
        $maxButtonWidth = 12
        $totalButtonWidth = ($maxButtonWidth * 2) + $buttonSpacing
        
        # Center buttons if dialog is wide enough
        if ($dialogWidth -gt $totalButtonWidth) {
            $buttonStartX = $centerX + [int](($dialogWidth - $totalButtonWidth) / 2)
            $buttonWidth = $maxButtonWidth
        } else {
            $buttonStartX = $centerX + 2
            $buttonWidth = [int](($dialogWidth - 4 - $buttonSpacing) / 2)
        }
        
        $this.SaveButton.SetBounds(
            $buttonStartX,
            $buttonY,
            $buttonWidth,
            $buttonHeight
        )
        
        $this.CancelButton.SetBounds(
            $buttonStartX + $buttonWidth + $buttonSpacing,
            $buttonY,
            $buttonWidth,
            $buttonHeight
        )
        
        # Store dialog bounds for rendering
        $this._dialogBounds = @{
            X = $centerX
            Y = $centerY
            Width = $dialogWidth
            Height = $dialogHeight
        }
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        # Focus on title box
        $this.TitleBox.Focus()
    }
    
    hidden [hashtable]$_dialogBounds
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new()
        
        # First, clear the entire screen with a dark overlay
        $overlayBg = [VT]::RGBBG(16, 16, 16)  # Dark gray overlay
        for ($y = 0; $y -lt $this.Height; $y++) {
            $sb.Append([VT]::MoveTo(0, $y))
            $sb.Append($overlayBg)
            $sb.Append(" " * $this.Width)
        }
        
        if ($this._dialogBounds) {
            # Draw dialog box
            $borderColor = $this.Theme.GetColor("dialog.border")
            $bgColor = $this.Theme.GetBgColor("dialog.background")
            $titleColor = $this.Theme.GetColor("dialog.title")
            
            $x = $this._dialogBounds.X
            $y = $this._dialogBounds.Y
            $w = $this._dialogBounds.Width
            $h = $this._dialogBounds.Height
            
            # Fill background
            for ($i = 0; $i -lt $h; $i++) {
                $sb.Append([VT]::MoveTo($x, $y + $i))
                $sb.Append($bgColor)
                $sb.Append(" " * $w)
            }
            
            # Draw border
            $sb.Append([VT]::MoveTo($x, $y))
            $sb.Append($borderColor)
            $sb.Append([VT]::TL() + ([VT]::H() * ($w - 2)) + [VT]::TR())
            
            for ($i = 1; $i -lt $h - 1; $i++) {
                $sb.Append([VT]::MoveTo($x, $y + $i))
                $sb.Append([VT]::V())
                $sb.Append([VT]::MoveTo($x + $w - 1, $y + $i))
                $sb.Append([VT]::V())
            }
            
            $sb.Append([VT]::MoveTo($x, $y + $h - 1))
            $sb.Append([VT]::BL() + ([VT]::H() * ($w - 2)) + [VT]::BR())
            
            # Draw title
            $title = " Edit Task "
            $titleX = $x + [int](($w - $title.Length) / 2)
            $sb.Append([VT]::MoveTo($titleX, $y))
            $sb.Append($titleColor)
            $sb.Append($title)
            
            # Draw labels
            $sb.Append([VT]::MoveTo($x + 2, $y + 1))
            $sb.Append($this.Theme.GetColor("foreground"))
            $sb.Append("Title:")
            
            $sb.Append([VT]::MoveTo($x + 2, $y + 5))
            $sb.Append("Description:")
            
            $sb.Append([VT]::MoveTo($x + 2, $y + 9))
            $sb.Append("Status:")
            
            $sb.Append([VT]::MoveTo($x + 24, $y + 9))
            $sb.Append("Priority:")
            
            $sb.Append([VT]::MoveTo($x + 46, $y + 9))
            $sb.Append("Progress (%):")
            
            # Draw task info
            $sb.Append([VT]::MoveTo($x + 2, $y + 16))
            $sb.Append($this.Theme.GetColor("disabled"))
            $sb.Append("Created: " + $this.Task.CreatedAt.ToString("yyyy-MM-dd HH:mm"))
            if ($this.Task.DueDate -ne [DateTime]::MinValue) {
                $sb.Append(" | Due: " + $this.Task.DueDate.ToString("yyyy-MM-dd"))
            }
        }
        
        # Render children
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $sb.Append($child.Render())
            }
        }
        
        $sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    [void] FocusNext() {
        $focusableChildren = $this.Children | Where-Object { $_.IsFocusable -and $_.Visible }
        if ($focusableChildren.Count -eq 0) { return }
        
        $currentIndex = -1
        for ($i = 0; $i -lt $focusableChildren.Count; $i++) {
            if ($focusableChildren[$i].IsFocused) {
                $currentIndex = $i
                break
            }
        }
        
        $nextIndex = ($currentIndex + 1) % $focusableChildren.Count
        $focusableChildren[$nextIndex].Focus()
    }
}
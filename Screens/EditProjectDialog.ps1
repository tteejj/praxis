# EditProjectDialog.ps1 - Dialog for editing existing projects

class EditProjectDialog : Screen {
    [Project]$Project
    [TextBox]$NameBox
    [TextBox]$NicknameBox
    [TextBox]$NoteBox
    [TextBox]$DueDateBox
    [Button]$SaveButton
    [Button]$CancelButton
    [scriptblock]$OnSave = {}
    [scriptblock]$OnCancel = {}
    
    EditProjectDialog([Project]$project) : base() {
        $this.Title = "Edit Project"
        $this.Project = $project
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        # Create name textbox
        $this.NameBox = [TextBox]::new()
        $this.NameBox.Text = $this.Project.FullProjectName
        $this.NameBox.Placeholder = "Enter project name..."
        $this.NameBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.NameBox)
        
        # Create nickname textbox
        $this.NicknameBox = [TextBox]::new()
        $this.NicknameBox.Text = $this.Project.Nickname
        $this.NicknameBox.Placeholder = "Enter nickname..."
        $this.NicknameBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.NicknameBox)
        
        # Create note textbox
        $this.NoteBox = [TextBox]::new()
        $this.NoteBox.Text = $this.Project.Note
        $this.NoteBox.Placeholder = "Enter notes (optional)..."
        $this.NoteBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.NoteBox)
        
        # Create due date textbox
        $this.DueDateBox = [TextBox]::new()
        $this.DueDateBox.Text = $this.Project.DateDue.ToString("yyyy-MM-dd")
        $this.DueDateBox.Placeholder = "YYYY-MM-DD"
        $this.DueDateBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.DueDateBox)
        
        # Create buttons
        $this.SaveButton = [Button]::new("Save")
        # Capture dialog reference
        $dialog = $this
        $this.SaveButton.OnClick = {
            if ($dialog.NameBox.Text.Trim()) {
                # Parse date
                $dueDate = $dialog.Project.DateDue
                $dateText = $dialog.DueDateBox.Text.Trim()
                if ($dateText) {
                    $parsedDate = [DateTime]::MinValue
                    if ([DateTime]::TryParse($dateText, [ref]$parsedDate)) {
                        $dueDate = $parsedDate
                    }
                }
                
                if ($dialog.OnSave) {
                    & $dialog.OnSave @{
                        FullProjectName = $dialog.NameBox.Text
                        Nickname = $dialog.NicknameBox.Text
                        Note = $dialog.NoteBox.Text
                        DateDue = $dueDate
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
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        # Focus on name box
        $this.NameBox.Focus()
    }
    
    [void] OnBoundsChanged() {
        # Dialog dimensions
        $dialogWidth = 60
        $dialogHeight = 18
        $centerX = [int](($this.Width - $dialogWidth) / 2)
        $centerY = [int](($this.Height - $dialogHeight) / 2)
        
        # Position components
        $this.NameBox.SetBounds($centerX + 2, $centerY + 2, $dialogWidth - 4, 3)
        $this.NicknameBox.SetBounds($centerX + 2, $centerY + 6, $dialogWidth - 4, 3)
        $this.NoteBox.SetBounds($centerX + 2, $centerY + 10, $dialogWidth - 4, 3)
        $this.DueDateBox.SetBounds($centerX + 2, $centerY + 14, 20, 3)
        
        # Position buttons (use similar logic to ProjectsScreen)
        $buttonY = $centerY + 14
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
            $title = " Edit Project "
            $titleX = $x + [int](($w - $title.Length) / 2)
            $sb.Append([VT]::MoveTo($titleX, $y))
            $sb.Append($titleColor)
            $sb.Append($title)
            
            # Draw labels
            $sb.Append([VT]::MoveTo($x + 2, $y + 1))
            $sb.Append($this.Theme.GetColor("foreground"))
            $sb.Append("Name:")
            
            $sb.Append([VT]::MoveTo($x + 2, $y + 5))
            $sb.Append("Nickname:")
            
            $sb.Append([VT]::MoveTo($x + 2, $y + 9))
            $sb.Append("Notes:")
            
            $sb.Append([VT]::MoveTo($x + 2, $y + 13))
            $sb.Append("Due Date:")
            
            # Draw project info
            $sb.Append([VT]::MoveTo($x + 25, $y + 13))
            $sb.Append($this.Theme.GetColor("disabled"))
            $sb.Append("Assigned: " + $this.Project.DateAssigned.ToString("yyyy-MM-dd"))
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
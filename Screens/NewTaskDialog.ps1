# NewTaskDialog.ps1 - Dialog for creating new tasks

class NewTaskDialog : Screen {
    [TextBox]$TitleBox
    [TextBox]$DescriptionBox
    [ListBox]$PriorityList
    [Button]$CreateButton
    [Button]$CancelButton
    [scriptblock]$OnCreate = {}  # Legacy callback support
    [scriptblock]$OnCancel = {}  # Legacy callback support
    [EventBus]$EventBus
    
    NewTaskDialog() : base() {
        $this.Title = "New Task"
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        # Get EventBus
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Create title textbox
        $this.TitleBox = [TextBox]::new()
        $this.TitleBox.Placeholder = "Enter task title..."
        $this.TitleBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.TitleBox)
        
        # Create description textbox
        $this.DescriptionBox = [TextBox]::new()
        $this.DescriptionBox.Placeholder = "Enter description (optional)..."
        $this.DescriptionBox.Initialize($global:ServiceContainer)
        $this.AddChild($this.DescriptionBox)
        
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
        $this.PriorityList.SelectIndex(1)  # Default to Medium
        $this.AddChild($this.PriorityList)
        
        # Create buttons
        $this.CreateButton = [Button]::new("Create")
        # Capture the dialog reference
        $dialog = $this
        $this.CreateButton.OnClick = {
            if ($dialog.TitleBox.Text.Trim()) {
                $selectedPriority = $dialog.PriorityList.GetSelectedItem()
                $taskData = @{
                    Title = $dialog.TitleBox.Text
                    Description = $dialog.DescriptionBox.Text
                    Priority = if ($selectedPriority) { $selectedPriority.Value } else { [TaskPriority]::Medium }
                    Status = [TaskStatus]::Pending
                    Progress = 0
                }
                
                # Use EventBus if available
                if ($dialog.EventBus) {
                    # Create task via service
                    $taskService = $global:ServiceContainer.GetService("TaskService")
                    if ($taskService) {
                        $newTask = $taskService.CreateTask($taskData)
                        
                        # Publish event
                        $dialog.EventBus.Publish([EventNames]::TaskCreated, @{ 
                            Task = $newTask 
                        })
                    }
                    
                    # Close dialog
                    $dialog.EventBus.Publish([EventNames]::DialogClosed, @{ 
                        Dialog = 'NewTaskDialog'
                        Result = 'Create'
                    })
                    
                    if ($global:ScreenManager) {
                        $global:ScreenManager.Pop()
                    }
                }
                # Fallback to callback if EventBus not available
                elseif ($dialog.OnCreate) {
                    & $dialog.OnCreate $taskData
                }
            }
        }.GetNewClosure()
        $this.CreateButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.CreateButton)
        
        $this.CancelButton = [Button]::new("Cancel")
        $this.CancelButton.OnClick = {
            # Use EventBus if available
            if ($dialog.EventBus) {
                $dialog.EventBus.Publish([EventNames]::DialogClosed, @{ 
                    Dialog = 'NewTaskDialog'
                    Result = 'Cancel'
                })
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }
            # Fallback to callback
            elseif ($dialog.OnCancel) {
                & $dialog.OnCancel
            }
        }.GetNewClosure()
        $this.CancelButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.CancelButton)
        
        # Key bindings
        $this.BindKey([System.ConsoleKey]::Escape, { 
            if ($this.EventBus) {
                $this.EventBus.Publish([EventNames]::DialogClosed, @{ 
                    Dialog = 'NewTaskDialog'
                    Result = 'Cancel'
                })
                
                if ($global:ScreenManager) {
                    $global:ScreenManager.Pop()
                }
            }
            elseif ($this.OnCancel) {
                & $this.OnCancel
            }
        })
        $this.BindKey([System.ConsoleKey]::Tab, { $this.FocusNext() })
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Publish dialog opened event
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::DialogOpened, @{ 
                Dialog = 'NewTaskDialog' 
            })
        }
        
        # Focus on title box
        $this.TitleBox.Focus()
    }
    
    [void] OnBoundsChanged() {
        # Dialog dimensions
        $dialogWidth = 60
        $dialogHeight = 20
        $centerX = [int](($this.Width - $dialogWidth) / 2)
        $centerY = [int](($this.Height - $dialogHeight) / 2)
        
        # Position components
        $this.TitleBox.Width = $dialogWidth - 4
        $this.TitleBox.SetBounds($centerX + 2, $centerY + 2, $dialogWidth - 4, 3)
        
        $this.DescriptionBox.Width = $dialogWidth - 4
        $this.DescriptionBox.SetBounds($centerX + 2, $centerY + 6, $dialogWidth - 4, 3)
        
        $this.PriorityList.Height = 5
        $this.PriorityList.SetBounds($centerX + 2, $centerY + 10, 20, 5)
        
        # Position buttons (use similar logic to ProjectsScreen)
        $buttonY = $centerY + 16  # 10 + 5 (list) + 1 (spacing)
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
        
        $this.CreateButton.SetBounds(
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
            $title = " New Task "
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
            $sb.Append("Priority:")
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
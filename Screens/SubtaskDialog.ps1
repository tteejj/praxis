# SubtaskDialog - Dialog for adding/editing subtasks

class SubtaskDialog : Screen {
    [Task]$ParentTask = $null
    [Subtask]$Subtask = $null  # For editing existing subtasks
    [bool]$IsEditMode = $false
    
    # Input fields
    [TextBox]$TitleTextBox
    [TextBox]$DescriptionTextBox
    [TextBox]$EstimatedTimeTextBox
    [TextBox]$ActualTimeTextBox
    [TextBox]$DueDateTextBox
    
    # Dropdowns (simplified as text for now)
    [TextBox]$PriorityTextBox
    [TextBox]$ProgressTextBox
    
    # Buttons
    [Button]$SaveButton
    [Button]$CancelButton
    
    # Callbacks
    [scriptblock]$OnSave = {}
    [scriptblock]$OnCancel = {}
    
    SubtaskDialog() : base() {
        $this.Title = "Add Subtask"
    }
    
    SubtaskDialog([Task]$parentTask) : base() {
        $this.ParentTask = $parentTask
        $this.Title = "Add Subtask - $($parentTask.Title)"
    }
    
    SubtaskDialog([Task]$parentTask, [Subtask]$subtask) : base() {
        $this.ParentTask = $parentTask
        $this.Subtask = $subtask
        $this.IsEditMode = $true
        $this.Title = "Edit Subtask - $($subtask.Title)"
    }
    
    [void] OnInitialize() {
        # Create input fields
        $this.TitleTextBox = [TextBox]::new()
        $this.TitleTextBox.Title = "Title"
        $this.TitleTextBox.ShowBorder = $true
        
        if ($this.IsEditMode -and $this.Subtask.Title) {
            $this.TitleTextBox.Text = $this.Subtask.Title
        }
        
        $this.DescriptionTextBox = [TextBox]::new()
        $this.DescriptionTextBox.Title = "Description"
        $this.DescriptionTextBox.ShowBorder = $true
        $this.DescriptionTextBox.IsMultiline = $true
        
        if ($this.IsEditMode -and $this.Subtask.Description) {
            $this.DescriptionTextBox.Text = $this.Subtask.Description
        }
        
        $this.PriorityTextBox = [TextBox]::new()
        $this.PriorityTextBox.Title = "Priority (Low/Medium/High)"
        $this.PriorityTextBox.ShowBorder = $true
        
        if ($this.IsEditMode) {
            $this.PriorityTextBox.Text = $this.Subtask.Priority.ToString()
        } else {
            $this.PriorityTextBox.Text = "Medium"
        }
        
        $this.ProgressTextBox = [TextBox]::new()
        $this.ProgressTextBox.Title = "Progress (0-100)"
        $this.ProgressTextBox.ShowBorder = $true
        
        if ($this.IsEditMode) {
            $this.ProgressTextBox.Text = $this.Subtask.Progress.ToString()
        } else {
            $this.ProgressTextBox.Text = "0"
        }
        
        $this.EstimatedTimeTextBox = [TextBox]::new()
        $this.EstimatedTimeTextBox.Title = "Estimated Time (minutes)"
        $this.EstimatedTimeTextBox.ShowBorder = $true
        
        if ($this.IsEditMode -and $this.Subtask.EstimatedMinutes -gt 0) {
            $this.EstimatedTimeTextBox.Text = $this.Subtask.EstimatedMinutes.ToString()
        }
        
        $this.ActualTimeTextBox = [TextBox]::new()
        $this.ActualTimeTextBox.Title = "Actual Time (minutes)"
        $this.ActualTimeTextBox.ShowBorder = $true
        
        if ($this.IsEditMode -and $this.Subtask.ActualMinutes -gt 0) {
            $this.ActualTimeTextBox.Text = $this.Subtask.ActualMinutes.ToString()
        }
        
        $this.DueDateTextBox = [TextBox]::new()
        $this.DueDateTextBox.Title = "Due Date (MM/DD/YYYY, optional)"
        $this.DueDateTextBox.ShowBorder = $true
        
        if ($this.IsEditMode -and $this.Subtask.DueDate -ne [DateTime]::MinValue) {
            $this.DueDateTextBox.Text = $this.Subtask.DueDate.ToString("MM/dd/yyyy")
        }
        
        # Initialize components
        if ($this.ServiceContainer) {
            $this.TitleTextBox.Initialize($this.ServiceContainer)
            $this.DescriptionTextBox.Initialize($this.ServiceContainer)
            $this.PriorityTextBox.Initialize($this.ServiceContainer)
            $this.ProgressTextBox.Initialize($this.ServiceContainer)
            $this.EstimatedTimeTextBox.Initialize($this.ServiceContainer)
            $this.ActualTimeTextBox.Initialize($this.ServiceContainer)
            $this.DueDateTextBox.Initialize($this.ServiceContainer)
        }
        
        # Create buttons
        $saveText = if ($this.IsEditMode) { "Update Subtask" } else { "Add Subtask" }
        $this.SaveButton = [Button]::new($saveText)
        $this.SaveButton.IsDefault = $true
        $this.SaveButton.OnClick = { $this.HandleSave() }
        
        $this.CancelButton = [Button]::new("Cancel")
        $this.CancelButton.OnClick = { $this.HandleCancel() }
        
        if ($this.ServiceContainer) {
            $this.SaveButton.Initialize($this.ServiceContainer)
            $this.CancelButton.Initialize($this.ServiceContainer)
        }
        
        # Add children
        $this.AddChild($this.TitleTextBox)
        $this.AddChild($this.DescriptionTextBox)
        $this.AddChild($this.PriorityTextBox)
        $this.AddChild($this.ProgressTextBox)
        $this.AddChild($this.EstimatedTimeTextBox)
        $this.AddChild($this.ActualTimeTextBox)
        $this.AddChild($this.DueDateTextBox)
        $this.AddChild($this.SaveButton)
        $this.AddChild($this.CancelButton)
        
        # Set initial focus
        $this.TitleTextBox.Focus()
    }
    
    [void] OnBoundsChanged() {
        # Layout: Stack inputs vertically with buttons at bottom
        $margin = 2
        $buttonHeight = 3
        $shortInputHeight = 3
        $tallInputHeight = 4
        
        $currentY = $this.Y + $margin
        $inputWidth = $this.Width - ($margin * 2)
        
        # Title input
        $this.TitleTextBox.SetBounds(
            $this.X + $margin,
            $currentY,
            $inputWidth,
            $shortInputHeight
        )
        $currentY += $shortInputHeight + 1
        
        # Description input (taller)
        $this.DescriptionTextBox.SetBounds(
            $this.X + $margin,
            $currentY,
            $inputWidth,
            $tallInputHeight
        )
        $currentY += $tallInputHeight + 1
        
        # Priority and Progress on same row
        $halfWidth = [int](($inputWidth - 2) / 2)
        $this.PriorityTextBox.SetBounds(
            $this.X + $margin,
            $currentY,
            $halfWidth,
            $shortInputHeight
        )
        
        $this.ProgressTextBox.SetBounds(
            $this.X + $margin + $halfWidth + 2,
            $currentY,
            $halfWidth,
            $shortInputHeight
        )
        $currentY += $shortInputHeight + 1
        
        # Estimated and Actual time on same row
        $this.EstimatedTimeTextBox.SetBounds(
            $this.X + $margin,
            $currentY,
            $halfWidth,
            $shortInputHeight
        )
        
        $this.ActualTimeTextBox.SetBounds(
            $this.X + $margin + $halfWidth + 2,
            $currentY,
            $halfWidth,
            $shortInputHeight
        )
        $currentY += $shortInputHeight + 1
        
        # Due date
        $this.DueDateTextBox.SetBounds(
            $this.X + $margin,
            $currentY,
            $inputWidth,
            $shortInputHeight
        )
        $currentY += $shortInputHeight + 2
        
        # Buttons at bottom
        $buttonWidth = 15
        $buttonSpacing = 4
        $totalButtonWidth = ($buttonWidth * 2) + $buttonSpacing
        $buttonStartX = $this.X + [int](($this.Width - $totalButtonWidth) / 2)
        $buttonY = $this.Y + $this.Height - $buttonHeight - 1
        
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
    }
    
    [void] HandleSave() {
        # Validate inputs
        $validationError = $this.ValidateInputs()
        if ($validationError) {
            # In a real implementation, show error dialog
            # For now, just return
            return
        }
        
        # Create subtask data
        $subtaskData = $this.CreateSubtaskData()
        
        if ($this.OnSave) {
            & $this.OnSave $subtaskData
        }
    }
    
    [void] HandleCancel() {
        if ($this.OnCancel) {
            & $this.OnCancel
        }
    }
    
    [string] ValidateInputs() {
        # Validate title
        $title = $this.TitleTextBox.Text.Trim()
        if ([string]::IsNullOrEmpty($title)) {
            return "Title is required"
        }
        
        # Validate priority
        $priority = $this.PriorityTextBox.Text.Trim()
        if ($priority -notin @("Low", "Medium", "High")) {
            return "Priority must be Low, Medium, or High"
        }
        
        # Validate progress
        $progressStr = $this.ProgressTextBox.Text.Trim()
        $progress = 0
        if (-not [string]::IsNullOrEmpty($progressStr)) {
            if (-not [int]::TryParse($progressStr, [ref]$progress) -or $progress -lt 0 -or $progress -gt 100) {
                return "Progress must be a number between 0 and 100"
            }
        }
        
        # Validate estimated time
        $estimatedStr = $this.EstimatedTimeTextBox.Text.Trim()
        if (-not [string]::IsNullOrEmpty($estimatedStr)) {
            $estimated = 0
            if (-not [int]::TryParse($estimatedStr, [ref]$estimated) -or $estimated -lt 0) {
                return "Estimated time must be a positive number"
            }
        }
        
        # Validate actual time
        $actualStr = $this.ActualTimeTextBox.Text.Trim()
        if (-not [string]::IsNullOrEmpty($actualStr)) {
            $actual = 0
            if (-not [int]::TryParse($actualStr, [ref]$actual) -or $actual -lt 0) {
                return "Actual time must be a positive number"
            }
        }
        
        # Validate due date
        $dueDateStr = $this.DueDateTextBox.Text.Trim()
        if (-not [string]::IsNullOrEmpty($dueDateStr)) {
            try {
                [DateTime]::Parse($dueDateStr) | Out-Null
            } catch {
                return "Invalid due date format. Use MM/DD/YYYY"
            }
        }
        
        return $null  # No validation errors
    }
    
    [PSCustomObject] CreateSubtaskData() {
        # Parse inputs
        $title = $this.TitleTextBox.Text.Trim()
        $description = $this.DescriptionTextBox.Text.Trim()
        $priorityStr = $this.PriorityTextBox.Text.Trim()
        $progressStr = $this.ProgressTextBox.Text.Trim()
        $estimatedStr = $this.EstimatedTimeTextBox.Text.Trim()
        $actualStr = $this.ActualTimeTextBox.Text.Trim()
        $dueDateStr = $this.DueDateTextBox.Text.Trim()
        
        # Convert priority
        $priority = switch ($priorityStr) {
            "Low" { [TaskPriority]::Low }
            "High" { [TaskPriority]::High }
            default { [TaskPriority]::Medium }
        }
        
        # Parse numbers
        $progress = if ([string]::IsNullOrEmpty($progressStr)) { 0 } else { [int]::Parse($progressStr) }
        $estimated = if ([string]::IsNullOrEmpty($estimatedStr)) { 0 } else { [int]::Parse($estimatedStr) }
        $actual = if ([string]::IsNullOrEmpty($actualStr)) { 0 } else { [int]::Parse($actualStr) }
        
        # Parse due date
        $dueDate = if ([string]::IsNullOrEmpty($dueDateStr)) {
            [DateTime]::MinValue
        } else {
            [DateTime]::Parse($dueDateStr)
        }
        
        # Create subtask data object
        $subtaskData = [PSCustomObject]@{
            Id = if ($this.IsEditMode) { $this.Subtask.Id } else { [guid]::NewGuid().ToString() }
            ParentTaskId = $this.ParentTask.Id
            Title = $title
            Description = $description
            Priority = $priority
            Progress = $progress
            EstimatedMinutes = $estimated
            ActualMinutes = $actual
            DueDate = $dueDate
            IsEditMode = $this.IsEditMode
        }
        
        return $subtaskData
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([System.ConsoleKey]::Enter) {
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
                    $this.HandleSave()
                    return $true
                }
            }
            ([System.ConsoleKey]::Escape) {
                $this.HandleCancel()
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                # Handle tab navigation between fields
                $focused = $this.FindFocused()
                if ($focused -eq $this.TitleTextBox) {
                    $this.DescriptionTextBox.Focus()
                } elseif ($focused -eq $this.DescriptionTextBox) {
                    $this.PriorityTextBox.Focus()
                } elseif ($focused -eq $this.PriorityTextBox) {
                    $this.ProgressTextBox.Focus()
                } elseif ($focused -eq $this.ProgressTextBox) {
                    $this.EstimatedTimeTextBox.Focus()
                } elseif ($focused -eq $this.EstimatedTimeTextBox) {
                    $this.ActualTimeTextBox.Focus()
                } elseif ($focused -eq $this.ActualTimeTextBox) {
                    $this.DueDateTextBox.Focus()
                } elseif ($focused -eq $this.DueDateTextBox) {
                    $this.SaveButton.Focus()
                } else {
                    $this.TitleTextBox.Focus()
                }
                return $true
            }
        }
        
        # Let base class handle other input
        return $false
    }
}
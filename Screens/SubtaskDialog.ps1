# SubtaskDialog - Dialog for adding/editing subtasks using BaseDialog

class SubtaskDialog : BaseDialog {
    [Task]$ParentTask = $null
    [Subtask]$Subtask = $null  # For editing existing subtasks
    [bool]$IsEditMode = $false
    
    # Input fields
    [MinimalTextBox]$TitleTextBox
    [MinimalTextBox]$DescriptionTextBox
    [MinimalTextBox]$EstimatedTimeTextBox
    [MinimalTextBox]$ActualTimeTextBox
    [MinimalTextBox]$DueDateTextBox
    
    # Dropdowns (simplified as text for now)
    [MinimalTextBox]$PriorityTextBox
    [MinimalTextBox]$ProgressTextBox
    
    SubtaskDialog() : base("Add Subtask", 60, 24) {
        $this.PrimaryButtonText = "Add Subtask"
        $this.SecondaryButtonText = "Cancel"
    }
    
    SubtaskDialog([Task]$parentTask) : base("Add Subtask - $($parentTask.Title)", 60, 24) {
        $this.ParentTask = $parentTask
        $this.PrimaryButtonText = "Add Subtask"
        $this.SecondaryButtonText = "Cancel"
    }
    
    SubtaskDialog([Task]$parentTask, $subtask) : base("Edit Subtask", 60, 24) {
        $this.ParentTask = $parentTask
        $this.Subtask = $subtask
        $this.IsEditMode = $true
        $this.PrimaryButtonText = "Update Subtask"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] InitializeContent() {
        # Create input fields
        $this.TitleTextBox = [MinimalTextBox]::new()
        $this.TitleTextBox.Placeholder = "Title"
        $this.TitleTextBox.ShowBorder = $false  # Dialog provides the border
        $this.TitleTextBox.Height = 1
        
        if ($this.IsEditMode -and $this.Subtask -and $this.Subtask.PSObject.Properties['Title']) {
            $this.TitleTextBox.Text = $this.Subtask.Title
        }
        $this.AddContentControl($this.TitleTextBox, 1)
        
        $this.DescriptionTextBox = [MinimalTextBox]::new()
        $this.DescriptionTextBox.Placeholder = "Description"
        $this.DescriptionTextBox.ShowBorder = $false  # Dialog provides the border
        $this.DescriptionTextBox.Height = 3  # Multi-line
        
        if ($this.IsEditMode -and $this.Subtask -and $this.Subtask.PSObject.Properties['Description']) {
            $this.DescriptionTextBox.Text = $this.Subtask.Description
        }
        $this.AddContentControl($this.DescriptionTextBox, 3)
        
        $this.PriorityTextBox = [MinimalTextBox]::new()
        $this.PriorityTextBox.Placeholder = "Priority (Low/Medium/High)"
        $this.PriorityTextBox.ShowBorder = $false  # Dialog provides the border
        $this.PriorityTextBox.Height = 1
        
        if ($this.IsEditMode -and $this.Subtask -and $this.Subtask.Priority) {
            $this.PriorityTextBox.Text = $this.Subtask.Priority.ToString()
        } else {
            $this.PriorityTextBox.Text = "Medium"
        }
        $this.AddContentControl($this.PriorityTextBox, 1)
        
        $this.ProgressTextBox = [MinimalTextBox]::new()
        $this.ProgressTextBox.Placeholder = "Progress (0-100)"
        $this.ProgressTextBox.ShowBorder = $false  # Dialog provides the border
        $this.ProgressTextBox.Height = 1
        
        if ($this.IsEditMode -and $this.Subtask) {
            $progress = if ($this.Subtask.PSObject.Properties['Progress']) { $this.Subtask.Progress } else { 0 }
            $this.ProgressTextBox.Text = $progress.ToString()
        } else {
            $this.ProgressTextBox.Text = "0"
        }
        $this.AddContentControl($this.ProgressTextBox, 1)
        
        $this.EstimatedTimeTextBox = [MinimalTextBox]::new()
        $this.EstimatedTimeTextBox.Placeholder = "Estimated Time (minutes)"
        $this.EstimatedTimeTextBox.ShowBorder = $false  # Dialog provides the border
        $this.EstimatedTimeTextBox.Height = 1
        
        if ($this.IsEditMode -and $this.Subtask) {
            $estimated = if ($this.Subtask.PSObject.Properties['EstimatedMinutes']) { $this.Subtask.EstimatedMinutes } else { 0 }
            if ($estimated -gt 0) {
                $this.EstimatedTimeTextBox.Text = $estimated.ToString()
            }
        }
        $this.AddContentControl($this.EstimatedTimeTextBox, 1)
        
        $this.ActualTimeTextBox = [MinimalTextBox]::new()
        $this.ActualTimeTextBox.Placeholder = "Actual Time (minutes)"
        $this.ActualTimeTextBox.ShowBorder = $false  # Dialog provides the border
        $this.ActualTimeTextBox.Height = 1
        
        if ($this.IsEditMode -and $this.Subtask) {
            $actual = if ($this.Subtask.PSObject.Properties['ActualMinutes']) { $this.Subtask.ActualMinutes } else { 0 }
            if ($actual -gt 0) {
                $this.ActualTimeTextBox.Text = $actual.ToString()
            }
        }
        $this.AddContentControl($this.ActualTimeTextBox, 1)
        
        $this.DueDateTextBox = [MinimalTextBox]::new()
        $this.DueDateTextBox.Placeholder = "Due Date (MM/DD/YYYY, optional)"
        $this.DueDateTextBox.ShowBorder = $false  # Dialog provides the border
        $this.DueDateTextBox.Height = 1
        
        if ($this.IsEditMode -and $this.Subtask) {
            $dueDate = if ($this.Subtask.PSObject.Properties['DueDate']) { $this.Subtask.DueDate } else { [DateTime]::MinValue }
            if ($dueDate -ne [DateTime]::MinValue) {
                $this.DueDateTextBox.Text = $dueDate.ToString("MM/dd/yyyy")
            }
        }
        $this.AddContentControl($this.DueDateTextBox, 1)
        
        # Set custom handlers for BaseDialog
        $dialog = $this
        $this.OnPrimary = {
            $dialog.HandleSave()
        }.GetNewClosure()
        
        $this.OnSecondary = {
            if ($dialog.OnCancel) {
                & $dialog.OnCancel
            }
            $dialog.CloseDialog()
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Custom layout: Stack inputs vertically
        $padding = $this.DialogPadding
        $currentY = $dialogY + 2  # Start after title
        $inputWidth = $this.DialogWidth - ($padding * 2)
        
        # Title label and input
        $currentY += 1  # Space before first field
        $this.TitleTextBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            1
        )
        $currentY += 2
        
        # Description input (taller)
        $currentY += 1  # Label space
        $this.DescriptionTextBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            3
        )
        $currentY += 4
        
        # Priority and Progress on same row
        $halfWidth = [int](($inputWidth - 2) / 2)
        $currentY += 1  # Label space
        $this.PriorityTextBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $halfWidth,
            1
        )
        
        $this.ProgressTextBox.SetBounds(
            $dialogX + $padding + $halfWidth + 2,
            $currentY,
            $halfWidth,
            1
        )
        $currentY += 2
        
        # Estimated and Actual time on same row
        $currentY += 1  # Label space
        $this.EstimatedTimeTextBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $halfWidth,
            1
        )
        
        $this.ActualTimeTextBox.SetBounds(
            $dialogX + $padding + $halfWidth + 2,
            $currentY,
            $halfWidth,
            1
        )
        $currentY += 2
        
        # Due date
        $currentY += 1  # Label space
        $this.DueDateTextBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            1
        )
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 2048
        
        # First render the base dialog
        $baseRender = ([BaseDialog]$this).OnRender()
        $sb.Append($baseRender)
        
        # Render field labels
        $labelColor = $this.Theme.GetColor("dialog.title")
        $padding = $this.DialogPadding
        
        # Title label
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding, $this.TitleTextBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Title:")
        $sb.Append([VT]::Reset())
        
        # Description label
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding, $this.DescriptionTextBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Description:")
        $sb.Append([VT]::Reset())
        
        # Priority and Progress labels
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding, $this.PriorityTextBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Priority:")
        $sb.Append([VT]::Reset())
        
        $halfWidth = [int](($this.DialogWidth - ($padding * 2) - 2) / 2)
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding + $halfWidth + 2, $this.ProgressTextBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Progress (%):")
        $sb.Append([VT]::Reset())
        
        # Estimated and Actual time labels
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding, $this.EstimatedTimeTextBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Estimated (min):")
        $sb.Append([VT]::Reset())
        
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding + $halfWidth + 2, $this.ActualTimeTextBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Actual (min):")
        $sb.Append([VT]::Reset())
        
        # Due date label
        $sb.Append([VT]::MoveTo($this._dialogBounds.X + $padding, $this.DueDateTextBox.Y - 1))
        $sb.Append($labelColor)
        $sb.Append("Due Date (MM/DD/YYYY):")
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
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
        
        # Close dialog after successful save
        $this.CloseDialog()
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
            Id = if ($this.IsEditMode -and $this.Subtask) { 
                if ($this.Subtask.PSObject.Properties['Id']) { $this.Subtask.Id } else { [guid]::NewGuid().ToString() }
            } else { 
                [guid]::NewGuid().ToString() 
            }
            ParentTaskId = $this.ParentTask.Id
            Title = $title
            Description = $description
            Status = if ($this.IsEditMode -and $this.Subtask) { 
                if ($this.Subtask.PSObject.Properties['Status']) { $this.Subtask.Status } else { [TaskStatus]::Pending }
            } else { 
                [TaskStatus]::Pending 
            }
            Priority = $priority
            Progress = $progress
            EstimatedMinutes = $estimated
            ActualMinutes = $actual
            DueDate = $dueDate
            IsEditMode = $this.IsEditMode
        }
        
        return $subtaskData
    }
    
    # Override HandleScreenInput to add Ctrl+Enter shortcut
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Let base class handle standard dialog shortcuts first
        if (([BaseDialog]$this).HandleScreenInput($key)) {
            return $true
        }
        
        # Add Ctrl+Enter shortcut for save
        if ($key.Key -eq [System.ConsoleKey]::Enter -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
            $this.HandleSave()
            return $true
        }
        
        return $false
    }
    
    # Legacy callback support
    [scriptblock]$OnSave = {}
    [scriptblock]$OnCancel = {}
}
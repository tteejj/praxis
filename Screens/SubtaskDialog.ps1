# SubtaskDialog - Dialog for adding/editing subtasks using BaseDialog

class SubtaskDialog : BaseDialog {
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
        $this.TitleTextBox = [TextBox]::new()
        $this.TitleTextBox.Title = "Title"
        $this.TitleTextBox.ShowBorder = $true
        $this.TitleTextBox.TabIndex = 1
        
        if ($this.IsEditMode -and $this.Subtask -and $this.Subtask.PSObject.Properties['Title']) {
            $this.TitleTextBox.Text = $this.Subtask.Title
        }
        $this.AddContentControl($this.TitleTextBox)
        
        $this.DescriptionTextBox = [TextBox]::new()
        $this.DescriptionTextBox.Title = "Description"
        $this.DescriptionTextBox.ShowBorder = $true
        $this.DescriptionTextBox.IsMultiline = $true
        $this.DescriptionTextBox.TabIndex = 2
        
        if ($this.IsEditMode -and $this.Subtask -and $this.Subtask.PSObject.Properties['Description']) {
            $this.DescriptionTextBox.Text = $this.Subtask.Description
        }
        $this.AddContentControl($this.DescriptionTextBox)
        
        $this.PriorityTextBox = [TextBox]::new()
        $this.PriorityTextBox.Title = "Priority (Low/Medium/High)"
        $this.PriorityTextBox.ShowBorder = $true
        $this.PriorityTextBox.TabIndex = 3
        
        if ($this.IsEditMode -and $this.Subtask -and $this.Subtask.Priority) {
            $this.PriorityTextBox.Text = $this.Subtask.Priority.ToString()
        } else {
            $this.PriorityTextBox.Text = "Medium"
        }
        $this.AddContentControl($this.PriorityTextBox)
        
        $this.ProgressTextBox = [TextBox]::new()
        $this.ProgressTextBox.Title = "Progress (0-100)"
        $this.ProgressTextBox.ShowBorder = $true
        $this.ProgressTextBox.TabIndex = 4
        
        if ($this.IsEditMode -and $this.Subtask) {
            $progress = if ($this.Subtask.PSObject.Properties['Progress']) { $this.Subtask.Progress } else { 0 }
            $this.ProgressTextBox.Text = $progress.ToString()
        } else {
            $this.ProgressTextBox.Text = "0"
        }
        $this.AddContentControl($this.ProgressTextBox)
        
        $this.EstimatedTimeTextBox = [TextBox]::new()
        $this.EstimatedTimeTextBox.Title = "Estimated Time (minutes)"
        $this.EstimatedTimeTextBox.ShowBorder = $true
        $this.EstimatedTimeTextBox.TabIndex = 5
        
        if ($this.IsEditMode -and $this.Subtask) {
            $estimated = if ($this.Subtask.PSObject.Properties['EstimatedMinutes']) { $this.Subtask.EstimatedMinutes } else { 0 }
            if ($estimated -gt 0) {
                $this.EstimatedTimeTextBox.Text = $estimated.ToString()
            }
        }
        $this.AddContentControl($this.EstimatedTimeTextBox)
        
        $this.ActualTimeTextBox = [TextBox]::new()
        $this.ActualTimeTextBox.Title = "Actual Time (minutes)"
        $this.ActualTimeTextBox.ShowBorder = $true
        $this.ActualTimeTextBox.TabIndex = 6
        
        if ($this.IsEditMode -and $this.Subtask) {
            $actual = if ($this.Subtask.PSObject.Properties['ActualMinutes']) { $this.Subtask.ActualMinutes } else { 0 }
            if ($actual -gt 0) {
                $this.ActualTimeTextBox.Text = $actual.ToString()
            }
        }
        $this.AddContentControl($this.ActualTimeTextBox)
        
        $this.DueDateTextBox = [TextBox]::new()
        $this.DueDateTextBox.Title = "Due Date (MM/DD/YYYY, optional)"
        $this.DueDateTextBox.ShowBorder = $true
        $this.DueDateTextBox.TabIndex = 7
        
        if ($this.IsEditMode -and $this.Subtask) {
            $dueDate = if ($this.Subtask.PSObject.Properties['DueDate']) { $this.Subtask.DueDate } else { [DateTime]::MinValue }
            if ($dueDate -ne [DateTime]::MinValue) {
                $this.DueDateTextBox.Text = $dueDate.ToString("MM/dd/yyyy")
            }
        }
        $this.AddContentControl($this.DueDateTextBox)
        
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
        $shortInputHeight = 3
        $tallInputHeight = 4
        $currentY = $dialogY + $padding
        $inputWidth = $this.DialogWidth - ($padding * 2)
        
        # Title input
        $this.TitleTextBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            $shortInputHeight
        )
        $currentY += $shortInputHeight + 1
        
        # Description input (taller)
        $this.DescriptionTextBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            $tallInputHeight
        )
        $currentY += $tallInputHeight + 1
        
        # Priority and Progress on same row
        $halfWidth = [int](($inputWidth - 2) / 2)
        $this.PriorityTextBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $halfWidth,
            $shortInputHeight
        )
        
        $this.ProgressTextBox.SetBounds(
            $dialogX + $padding + $halfWidth + 2,
            $currentY,
            $halfWidth,
            $shortInputHeight
        )
        $currentY += $shortInputHeight + 1
        
        # Estimated and Actual time on same row
        $this.EstimatedTimeTextBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $halfWidth,
            $shortInputHeight
        )
        
        $this.ActualTimeTextBox.SetBounds(
            $dialogX + $padding + $halfWidth + 2,
            $currentY,
            $halfWidth,
            $shortInputHeight
        )
        $currentY += $shortInputHeight + 1
        
        # Due date
        $this.DueDateTextBox.SetBounds(
            $dialogX + $padding,
            $currentY,
            $inputWidth,
            $shortInputHeight
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
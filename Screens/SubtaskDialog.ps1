# SubtaskDialog - Dialog for adding/editing subtasks using UnifiedDialog

class SubtaskDialog : UnifiedDialog {
    [Task]$ParentTask = $null
    [Subtask]$Subtask = $null  # For editing existing subtasks
    [bool]$IsEditMode = $false
    
    SubtaskDialog() : base("Add Subtask", 50, 16) {
        $this.InitializeDialog()
    }
    
    SubtaskDialog([Task]$parentTask) : base("Add Subtask", 50, 16) {
        $this.ParentTask = $parentTask
        $this.InitializeDialog()
    }
    
    SubtaskDialog([Task]$parentTask, $subtask) : base("Edit Subtask", 50, 16) {
        $this.ParentTask = $parentTask
        $this.Subtask = $subtask
        $this.IsEditMode = $true
        $this.InitializeDialog()
    }
    
    [void] InitializeDialog() {
        # Add fields using UnifiedDialog API
        $titleValue = if ($this.IsEditMode -and $this.Subtask) { $this.Subtask.Title } else { "" }
        $this.AddField("title", "Title", $titleValue)
        
        $descriptionValue = if ($this.IsEditMode -and $this.Subtask -and $this.Subtask.PSObject.Properties['Description']) { $this.Subtask.Description } else { "" }
        $this.AddField("description", "Description", $descriptionValue)
        
        $priorityValue = if ($this.IsEditMode -and $this.Subtask -and $this.Subtask.Priority) { $this.Subtask.Priority.ToString() } else { "Medium" }
        $this.AddField("priority", "Priority (Low/Medium/High)", $priorityValue)
        
        $progressValue = if ($this.IsEditMode -and $this.Subtask) { 
            $progress = if ($this.Subtask.PSObject.Properties['Progress']) { $this.Subtask.Progress } else { 0 }
            $progress.ToString()
        } else { "0" }
        $this.AddField("progress", "Progress (0-100)", $progressValue)
        
        $estimatedValue = if ($this.IsEditMode -and $this.Subtask) {
            $estimated = if ($this.Subtask.PSObject.Properties['EstimatedMinutes']) { $this.Subtask.EstimatedMinutes } else { 0 }
            if ($estimated -gt 0) { $estimated.ToString() } else { "" }
        } else { "" }
        $this.AddField("estimatedTime", "Estimated Time (minutes)", $estimatedValue)
        
        $actualValue = if ($this.IsEditMode -and $this.Subtask) {
            $actual = if ($this.Subtask.PSObject.Properties['ActualMinutes']) { $this.Subtask.ActualMinutes } else { 0 }
            if ($actual -gt 0) { $actual.ToString() } else { "" }
        } else { "" }
        $this.AddField("actualTime", "Actual Time (minutes)", $actualValue)
        
        $dueDateValue = if ($this.IsEditMode -and $this.Subtask) {
            $dueDate = if ($this.Subtask.PSObject.Properties['DueDate']) { $this.Subtask.DueDate } else { [DateTime]::MinValue }
            if ($dueDate -ne [DateTime]::MinValue) { $dueDate.ToString("MM/dd/yyyy") } else { "" }
        } else { "" }
        $this.AddField("dueDate", "Due Date (MM/DD/YYYY)", $dueDateValue)
        
        # Set button labels based on mode
        if ($this.IsEditMode) {
            $this.SetButtons("Save", "Cancel")
        } else {
            $this.SetButtons("Create", "Cancel")
        }
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.HandleSave() }.GetNewClosure()
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
        $this.Close()
    }
    
    [string] ValidateInputs() {
        # Validate title
        $title = $this.GetFieldValue("title").Trim()
        if ([string]::IsNullOrEmpty($title)) {
            return "Title is required"
        }
        
        # Validate priority
        $priority = $this.GetFieldValue("priority").Trim()
        if ($priority -notin @("Low", "Medium", "High")) {
            return "Priority must be Low, Medium, or High"
        }
        
        # Validate progress
        $progressStr = $this.GetFieldValue("progress").Trim()
        $progress = 0
        if (-not [string]::IsNullOrEmpty($progressStr)) {
            if (-not [int]::TryParse($progressStr, [ref]$progress) -or $progress -lt 0 -or $progress -gt 100) {
                return "Progress must be a number between 0 and 100"
            }
        }
        
        # Validate estimated time
        $estimatedStr = $this.GetFieldValue("estimatedTime").Trim()
        if (-not [string]::IsNullOrEmpty($estimatedStr)) {
            $estimated = 0
            if (-not [int]::TryParse($estimatedStr, [ref]$estimated) -or $estimated -lt 0) {
                return "Estimated time must be a positive number"
            }
        }
        
        # Validate actual time
        $actualStr = $this.GetFieldValue("actualTime").Trim()
        if (-not [string]::IsNullOrEmpty($actualStr)) {
            $actual = 0
            if (-not [int]::TryParse($actualStr, [ref]$actual) -or $actual -lt 0) {
                return "Actual time must be a positive number"
            }
        }
        
        # Validate due date
        $dueDateStr = $this.GetFieldValue("dueDate").Trim()
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
        # Parse inputs using UnifiedDialog API
        $title = $this.GetFieldValue("title").Trim()
        $description = $this.GetFieldValue("description").Trim()
        $priorityStr = $this.GetFieldValue("priority").Trim()
        $progressStr = $this.GetFieldValue("progress").Trim()
        $estimatedStr = $this.GetFieldValue("estimatedTime").Trim()
        $actualStr = $this.GetFieldValue("actualTime").Trim()
        $dueDateStr = $this.GetFieldValue("dueDate").Trim()
        
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
        if (([UnifiedDialog]$this).HandleScreenInput($key)) {
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
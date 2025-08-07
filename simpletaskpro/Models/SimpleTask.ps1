# SimpleTask.ps1 - Task model with subtasks

class SimpleTask {
    [string]$Id
    [string]$Title
    [bool]$Completed
    [string]$Priority  # High, Medium, Low
    [datetime]$DueDate
    [string]$Notes     # Only parent tasks have notes
    [string]$ParentId  # null for parent tasks
    [bool]$SubtasksCollapsed = $false  # Only parent tasks use this
    [string]$ColorTheme = "default"    # Per-task color theme
    [string]$SubtaskColorTheme = "default"  # Per-task subtask color
    [int]$SortOrder = 0               # Manual ordering
    [string[]]$Tags = @()             # Filter/search tags
    [System.Collections.Generic.List[SimpleTask]]$Subtasks
    [datetime]$CreatedDate
    [datetime]$ModifiedDate
    
    # Project management fields (Phase 1)
    [string]$ProjectFolderPath = ""      # Path to project folder
    [string]$T2020CallLogFile = ""       # Full path to T2020 call log file
    [string]$ExportDataFile = ""         # Full path to ExcelDataFlow export file
    [string]$ActionLogName = "action-log" # Name of action log file (without extension)
    [string]$ID1 = ""                    # Project code (3 chars display)
    [string]$ID2 = ""                    # Unique project ID (12 chars display)
    
    SimpleTask() {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.CreatedDate = Get-Date
        $this.ModifiedDate = Get-Date
        $this.Completed = $false
        $this.Priority = "Medium"
        $this.Notes = ""
        $this.Subtasks = [System.Collections.Generic.List[SimpleTask]]::new()
    }
    
    SimpleTask([string]$title) {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.Title = $title
        $this.CreatedDate = Get-Date
        $this.ModifiedDate = Get-Date
        $this.Completed = $false
        $this.Priority = "Medium"
        $this.Notes = ""
        $this.Subtasks = [System.Collections.Generic.List[SimpleTask]]::new()
    }
    
    [void] AddSubtask([SimpleTask]$subtask) {
        $subtask.ParentId = $this.Id
        $this.Subtasks.Add($subtask)
    }
    
    [bool] IsParent() {
        return [string]::IsNullOrEmpty($this.ParentId)
    }
    
    [string] GetStatusIcon() {
        if ($this.Completed) { 
            return "✓" 
        } else { 
            return "☐" 
        }
    }
    
    [string] GetPriorityDisplay() {
        switch ($this.Priority) {
            "High" { return "High" }
            "Medium" { return "Med " }
            "Low" { return "Low " }
        }
        return "    "
    }
    
    [string] GetDueDateDisplay() {
        if ($this.DueDate -eq [datetime]::MinValue) {
            return "-"
        }
        
        $days = ($this.DueDate.Date - (Get-Date).Date).Days
        
        if ($days -lt 0) {
            return "Overdue"
        } elseif ($days -eq 0) {
            return "Today"
        } elseif ($days -eq 1) {
            return "Tomorrow"
        } elseif ($days -le 7) {
            return "${days}d"
        } else {
            return $this.DueDate.ToString("MM/dd")
        }
    }
}
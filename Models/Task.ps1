# Task.ps1 - Task model

enum TaskStatus {
    Pending
    InProgress
    Completed
    Cancelled
}

enum TaskPriority {
    Low
    Medium
    High
}

class Task {
    [string]$Id
    [string]$Title
    [string]$Description = ""
    [TaskStatus]$Status = [TaskStatus]::Pending
    [TaskPriority]$Priority = [TaskPriority]::Medium
    [int]$Progress = 0
    [string]$ProjectId = ""
    [string[]]$Tags = @()
    [DateTime]$DueDate = [DateTime]::MinValue
    [DateTime]$CreatedAt
    [DateTime]$UpdatedAt
    [bool]$Deleted = $false
    
    Task() {
        $this.Id = [guid]::NewGuid().ToString()
        $this.CreatedAt = Get-Date
        $this.UpdatedAt = $this.CreatedAt
    }
    
    # Helper methods
    [bool] IsOverdue() {
        return $this.DueDate -ne [DateTime]::MinValue -and 
               $this.DueDate -lt [DateTime]::Now -and 
               $this.Status -ne [TaskStatus]::Completed -and
               $this.Status -ne [TaskStatus]::Cancelled
    }
    
    [int] GetDaysUntilDue() {
        if ($this.DueDate -eq [DateTime]::MinValue) {
            return [int]::MaxValue
        }
        return ([DateTime]$this.DueDate - [DateTime]::Now).Days
    }
    
    [string] GetStatusDisplay() {
        switch ($this.Status) {
            ([TaskStatus]::Pending) { return "[ ]" }
            ([TaskStatus]::InProgress) { return "[~]" }
            ([TaskStatus]::Completed) { return "[✓]" }
            ([TaskStatus]::Cancelled) { return "[✗]" }
        }
        return "[?]"
    }
    
    [string] GetPriorityDisplay() {
        switch ($this.Priority) {
            ([TaskPriority]::Low) { return "↓" }
            ([TaskPriority]::Medium) { return "→" }
            ([TaskPriority]::High) { return "↑" }
        }
        return " "
    }
    
    [void] UpdateProgress([int]$progress) {
        $this.Progress = [Math]::Max(0, [Math]::Min(100, $progress))
        $this.UpdatedAt = Get-Date
        
        # Auto-update status based on progress
        if ($this.Progress -eq 100 -and $this.Status -ne [TaskStatus]::Completed) {
            $this.Status = [TaskStatus]::Completed
        } elseif ($this.Progress -gt 0 -and $this.Progress -lt 100 -and $this.Status -eq [TaskStatus]::Pending) {
            $this.Status = [TaskStatus]::InProgress
        }
    }
}
# Subtask.ps1 - Subtask model extending the Task system

class Subtask : BaseModel {
    [string]$ParentTaskId  # Links to parent Task.Id
    [string]$Title
    [string]$Description = ""
    [TaskStatus]$Status = [TaskStatus]::Pending
    [TaskPriority]$Priority = [TaskPriority]::Medium
    [int]$Progress = 0
    [int]$SortOrder = 0  # For ordering subtasks within parent
    [string[]]$Tags = @()
    [DateTime]$DueDate = [DateTime]::MinValue
    
    # Estimated and actual time tracking
    [int]$EstimatedMinutes = 0
    [int]$ActualMinutes = 0
    
    Subtask() : base() {
        # BaseModel handles Id, CreatedAt, UpdatedAt, Deleted initialization
    }
    
    Subtask([string]$parentTaskId) : base() {
        $this.ParentTaskId = $parentTaskId
        # BaseModel handles Id, CreatedAt, UpdatedAt, Deleted initialization
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
    
    [string] GetDurationDisplay() {
        if ($this.EstimatedMinutes -eq 0) {
            return ""
        }
        
        $estimated = $this.FormatMinutes($this.EstimatedMinutes)
        if ($this.ActualMinutes -gt 0) {
            $actual = $this.FormatMinutes($this.ActualMinutes)
            return "$actual / $estimated"
        } else {
            return "~$estimated"
        }
    }
    
    [string] FormatMinutes([int]$minutes) {
        if ($minutes -lt 60) {
            return "$($minutes)m"
        } elseif ($minutes -lt 480) {  # Less than 8 hours
            $hours = [Math]::Floor($minutes / 60)
            $mins = $minutes % 60
            if ($mins -eq 0) {
                return "$($hours)h"
            } else {
                return "$($hours)h$($mins)m"
            }
        } else {
            $hours = [Math]::Round($minutes / 60.0, 1)
            return "$($hours)h"
        }
    }
    
    [bool] IsCompleted() {
        return $this.Status -eq [TaskStatus]::Completed
    }
    
    [bool] IsInProgress() {
        return $this.Status -eq [TaskStatus]::InProgress
    }
    
    [bool] IsPending() {
        return $this.Status -eq [TaskStatus]::Pending
    }
}
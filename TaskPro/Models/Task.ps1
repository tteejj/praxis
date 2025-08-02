# Task.ps1 - Simple task model with notes

class Task {
    [string]$Id
    [string]$Title
    [bool]$Completed
    [datetime]$DueDate
    [string]$Priority  # High, Medium, Low
    [string]$Project
    [string]$Notes     # Full markdown notes for the task
    [datetime]$CreatedDate
    [datetime]$ModifiedDate
    
    Task() {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.CreatedDate = Get-Date
        $this.ModifiedDate = Get-Date
        $this.Completed = $false
        $this.Priority = "Medium"
        $this.Notes = ""
    }
    
    Task([string]$title) {
        $this.Id = [Guid]::NewGuid().ToString()
        $this.Title = $title
        $this.CreatedDate = Get-Date
        $this.ModifiedDate = Get-Date
        $this.Completed = $false
        $this.Priority = "Medium"
        $this.Notes = ""
    }
    
    [string] GetStatusIcon() {
        if ($this.Completed) { 
            return "✓" 
        } else { 
            return "☐" 
        }
    }
    
    [string] GetPriorityColor() {
        switch ($this.Priority) {
            "High" { return "`e[91m" }    # Bright red
            "Medium" { return "`e[93m" }  # Bright yellow
            "Low" { return "`e[92m" }     # Bright green
        }
        return "`e[0m"  # Default - reset
    }
    
    [string] GetDueDateDisplay() {
        if ($this.DueDate -eq [datetime]::MinValue) {
            return "-"
        }
        
        $days = ($this.DueDate.Date - (Get-Date).Date).Days
        $dateStr = $this.DueDate.ToString("MM/dd")
        
        if ($days -lt 0) {
            return "`e[91m$dateStr!`e[0m"  # Red with !
        } elseif ($days -eq 0) {
            return "`e[93mToday`e[0m"      # Yellow
        } elseif ($days -eq 1) {
            return "`e[93mTomorrow`e[0m"   # Yellow
        } elseif ($days -le 7) {
            return "`e[92m$dateStr`e[0m"   # Green
        } else {
            return $dateStr
        }
    }
}
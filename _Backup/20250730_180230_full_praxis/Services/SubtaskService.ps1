# SubtaskService.ps1 - Service for managing subtasks

class SubtaskService {
    [System.Collections.Generic.List[Subtask]]$Subtasks
    hidden [string]$DataPath
    hidden [bool]$_isDirty = $false
    
    SubtaskService() {
        $this.Subtasks = [System.Collections.Generic.List[Subtask]]::new()
        
        # Set data path
        $dataDir = Join-Path $global:PraxisRoot "_ProjectData"
        $this.DataPath = Join-Path $dataDir "subtasks.json"
        
        # Load existing subtasks
        $this.Load()
    }
    
    # CRUD Operations
    [Subtask] AddSubtask([string]$parentTaskId, [string]$title) {
        $subtask = [Subtask]::new($parentTaskId)
        $subtask.Title = $title
        
        # Set sort order to be last among siblings
        $siblings = $this.GetSubtasksForTask($parentTaskId)
        if ($siblings.Count -gt 0) {
            $maxOrder = ($siblings | Measure-Object SortOrder -Maximum).Maximum
            $subtask.SortOrder = $maxOrder + 1
        } else {
            $subtask.SortOrder = 0
        }
        
        $this.Subtasks.Add($subtask)
        $this._isDirty = $true
        $this.Save()
        
        return $subtask
    }
    
    [Subtask] CreateSubtask([hashtable]$properties) {
        $subtask = [Subtask]::new()
        
        # Set properties from hashtable
        foreach ($key in $properties.Keys) {
            if ($key -eq 'Progress') {
                # Use UpdateProgress to auto-handle status changes
                $subtask.UpdateProgress($properties[$key])
            } elseif ($subtask.PSObject.Properties.Name -contains $key) {
                $subtask.$key = $properties[$key]
            }
        }
        
        # Ensure sort order is set
        if (-not $properties.ContainsKey('SortOrder')) {
            $siblings = $this.GetSubtasksForTask($subtask.ParentTaskId)
            if ($siblings.Count -gt 0) {
                $maxOrder = ($siblings | Measure-Object SortOrder -Maximum).Maximum
                $subtask.SortOrder = $maxOrder + 1
            } else {
                $subtask.SortOrder = 0
            }
        }
        
        $this.Subtasks.Add($subtask)
        $this._isDirty = $true
        $this.Save()
        
        return $subtask
    }
    
    [Subtask] GetSubtask([string]$id) {
        return $this.Subtasks | Where-Object { $_.Id -eq $id -and -not $_.Deleted } | Select-Object -First 1
    }
    
    [System.Collections.Generic.List[Subtask]] GetSubtasksForTask([string]$parentTaskId) {
        $taskSubtasks = [System.Collections.Generic.List[Subtask]]::new()
        
        foreach ($subtask in $this.Subtasks) {
            if ($subtask.ParentTaskId -eq $parentTaskId -and -not $subtask.Deleted) {
                $taskSubtasks.Add($subtask)
            }
        }
        
        # Sort by SortOrder
        return $taskSubtasks | Sort-Object SortOrder
    }
    
    [System.Collections.Generic.List[Subtask]] GetAllSubtasks() {
        $activeSubtasks = [System.Collections.Generic.List[Subtask]]::new()
        
        foreach ($subtask in $this.Subtasks) {
            if (-not $subtask.Deleted) {
                $activeSubtasks.Add($subtask)
            }
        }
        
        return $activeSubtasks
    }
    
    [void] UpdateSubtask([Subtask]$subtask) {
        $existingSubtask = $this.GetSubtask($subtask.Id)
        if ($existingSubtask) {
            $existingSubtask.Title = $subtask.Title
            $existingSubtask.Description = $subtask.Description
            $existingSubtask.Status = $subtask.Status
            $existingSubtask.Priority = $subtask.Priority
            $existingSubtask.UpdateProgress($subtask.Progress)  # Use UpdateProgress to auto-handle status
            $existingSubtask.DueDate = $subtask.DueDate
            $existingSubtask.Tags = $subtask.Tags
            $existingSubtask.EstimatedMinutes = $subtask.EstimatedMinutes
            $existingSubtask.ActualMinutes = $subtask.ActualMinutes
            
            $this._isDirty = $true
            $this.Save()
        }
    }
    
    [void] DeleteSubtask([string]$id) {
        $subtask = $this.GetSubtask($id)
        if ($subtask) {
            $subtask.Deleted = $true
            $subtask.UpdatedAt = Get-Date
            $this._isDirty = $true
            $this.Save()
        }
    }
    
    [void] CompleteSubtask([string]$id) {
        $subtask = $this.GetSubtask($id)
        if ($subtask) {
            $subtask.Status = [TaskStatus]::Completed
            $subtask.Progress = 100
            $subtask.UpdatedAt = Get-Date
            $this._isDirty = $true
            $this.Save()
        }
    }
    
    [void] ReorderSubtasks([string]$parentTaskId, [string[]]$subtaskIds) {
        $sortOrder = 0
        foreach ($subtaskId in $subtaskIds) {
            $subtask = $this.GetSubtask($subtaskId)
            if ($subtask -and $subtask.ParentTaskId -eq $parentTaskId) {
                $subtask.SortOrder = $sortOrder
                $subtask.UpdatedAt = Get-Date
                $sortOrder++
            }
        }
        $this._isDirty = $true
        $this.Save()
    }
    
    # Calculate parent task progress based on subtask completion
    [int] CalculateTaskProgress([string]$parentTaskId) {
        $taskSubtasks = $this.GetSubtasksForTask($parentTaskId)
        
        if ($taskSubtasks.Count -eq 0) {
            return 0
        }
        
        $totalProgress = 0
        foreach ($subtask in $taskSubtasks) {
            $totalProgress += $subtask.Progress
        }
        
        return [Math]::Floor($totalProgress / $taskSubtasks.Count)
    }
    
    [hashtable] GetTaskStatistics([string]$parentTaskId) {
        $taskSubtasks = $this.GetSubtasksForTask($parentTaskId)
        
        $stats = @{
            Total = $taskSubtasks.Count
            Completed = 0
            InProgress = 0
            Pending = 0
            Overdue = 0
            EstimatedMinutes = 0
            ActualMinutes = 0
        }
        
        foreach ($subtask in $taskSubtasks) {
            switch ($subtask.Status) {
                ([TaskStatus]::Completed) { $stats.Completed++ }
                ([TaskStatus]::InProgress) { $stats.InProgress++ }
                ([TaskStatus]::Pending) { $stats.Pending++ }
            }
            
            if ($subtask.IsOverdue()) {
                $stats.Overdue++
            }
            
            $stats.EstimatedMinutes += $subtask.EstimatedMinutes
            $stats.ActualMinutes += $subtask.ActualMinutes
        }
        
        return $stats
    }
    
    # Data persistence
    [void] Save() {
        if (-not $this._isDirty) {
            return
        }
        
        try {
            # Convert to serializable format
            $data = @()
            foreach ($subtask in $this.Subtasks) {
                $data += @{
                    Id = $subtask.Id
                    ParentTaskId = $subtask.ParentTaskId
                    Title = $subtask.Title
                    Description = $subtask.Description
                    Status = [int]$subtask.Status
                    Priority = [int]$subtask.Priority
                    Progress = $subtask.Progress
                    SortOrder = $subtask.SortOrder
                    Tags = $subtask.Tags
                    DueDate = if ($subtask.DueDate -eq [DateTime]::MinValue) { "" } else { $subtask.DueDate.ToString("yyyy-MM-ddTHH:mm:ss") }
                    CreatedAt = $subtask.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ss")
                    UpdatedAt = $subtask.UpdatedAt.ToString("yyyy-MM-ddTHH:mm:ss")
                    EstimatedMinutes = $subtask.EstimatedMinutes
                    ActualMinutes = $subtask.ActualMinutes
                    Deleted = $subtask.Deleted
                }
            }
            
            $json = $data | ConvertTo-Json -Depth 10
            Set-Content -Path $this.DataPath -Value $json -Encoding UTF8
            $this._isDirty = $false
            
        } catch {
            Write-Error "Failed to save subtasks: $($_.Exception.Message)"
        }
    }
    
    [void] Load() {
        if (-not (Test-Path $this.DataPath)) {
            return
        }
        
        try {
            $json = Get-Content -Path $this.DataPath -Raw -Encoding UTF8
            $data = $json | ConvertFrom-Json
            
            $this.Subtasks.Clear()
            
            foreach ($item in $data) {
                $subtask = [Subtask]::new()
                $subtask.Id = $item.Id
                $subtask.ParentTaskId = $item.ParentTaskId
                $subtask.Title = $item.Title
                $subtask.Description = $item.Description
                $subtask.Status = [TaskStatus]$item.Status
                $subtask.Priority = [TaskPriority]$item.Priority
                $subtask.Progress = $item.Progress
                $subtask.SortOrder = $item.SortOrder
                $subtask.Tags = $item.Tags
                $subtask.DueDate = if ([string]::IsNullOrEmpty($item.DueDate)) { [DateTime]::MinValue } else { [DateTime]::Parse($item.DueDate) }
                $subtask.CreatedAt = [DateTime]::Parse($item.CreatedAt)
                $subtask.UpdatedAt = [DateTime]::Parse($item.UpdatedAt)
                $subtask.EstimatedMinutes = if ($item.PSObject.Properties.Name -contains 'EstimatedMinutes') { $item.EstimatedMinutes } else { 0 }
                $subtask.ActualMinutes = if ($item.PSObject.Properties.Name -contains 'ActualMinutes') { $item.ActualMinutes } else { 0 }
                $subtask.Deleted = if ($item.PSObject.Properties.Name -contains 'Deleted') { $item.Deleted } else { $false }
                
                $this.Subtasks.Add($subtask)
            }
            
            $this._isDirty = $false
            
        } catch {
            Write-Error "Failed to load subtasks: $($_.Exception.Message)"
        }
    }
}
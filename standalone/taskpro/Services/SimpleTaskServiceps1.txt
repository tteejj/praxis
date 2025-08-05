# SimpleTaskService.ps1 - Task storage with parent/subtask support

class SimpleTaskService {
    [string]$DataFile
    [System.Collections.Generic.List[SimpleTask]]$Tasks
    
    SimpleTaskService() {
        $this.DataFile = Join-Path $PSScriptRoot "../Data/tasks.json"
        $this.Tasks = [System.Collections.Generic.List[SimpleTask]]::new()
        $this.EnsureDataDirectory()
        $this.Load()
    }
    
    [void] EnsureDataDirectory() {
        $dataDir = Split-Path $this.DataFile -Parent
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }
    }
    
    [void] Load() {
        if (Test-Path $this.DataFile) {
            try {
                $json = Get-Content $this.DataFile -Raw
                $data = ConvertFrom-Json $json
                
                $this.Tasks.Clear()
                
                # First pass: Load all tasks
                $taskMap = @{}
                foreach ($taskData in $data) {
                    $task = [SimpleTask]::new()
                    $task.Id = $taskData.Id
                    $task.Title = $taskData.Title
                    $task.Completed = $taskData.Completed
                    $task.Priority = $taskData.Priority
                    $task.Notes = $taskData.Notes
                    $task.ParentId = $taskData.ParentId
                    if ($taskData.PSObject.Properties['SubtasksCollapsed']) {
                        $task.SubtasksCollapsed = $taskData.SubtasksCollapsed
                    }
                    if ($taskData.PSObject.Properties['ColorTheme']) {
                        $task.ColorTheme = $taskData.ColorTheme
                    }
                    if ($taskData.PSObject.Properties['SubtaskColorTheme']) {
                        $task.SubtaskColorTheme = $taskData.SubtaskColorTheme
                    }
                    if ($taskData.PSObject.Properties['SortOrder']) {
                        $task.SortOrder = $taskData.SortOrder
                    }
                    if ($taskData.PSObject.Properties['Tags']) {
                        $task.Tags = $taskData.Tags
                    }
                    
                    if ($taskData.DueDate) {
                        $task.DueDate = [datetime]::Parse($taskData.DueDate)
                    }
                    if ($taskData.CreatedDate) {
                        $task.CreatedDate = [datetime]::Parse($taskData.CreatedDate)
                    }
                    if ($taskData.ModifiedDate) {
                        $task.ModifiedDate = [datetime]::Parse($taskData.ModifiedDate)
                    }
                    
                    $taskMap[$task.Id] = $task
                }
                
                # Second pass: Build parent-child relationships
                foreach ($task in $taskMap.Values) {
                    if ($task.IsParent()) {
                        $this.Tasks.Add($task)
                    } else {
                        $parent = $taskMap[$task.ParentId]
                        if ($parent) {
                            $parent.Subtasks.Add($task)
                        }
                    }
                }
            } catch {
                Write-Warning "Failed to load tasks: $_"
                $this.CreateSampleTasks()
            }
        } else {
            $this.CreateSampleTasks()
        }
    }
    
    [void] Save() {
        try {
            $data = @()
            
            # Save parent tasks and their subtasks
            foreach ($task in $this.Tasks) {
                # Parent task
                $data += $this.TaskToData($task)
                
                # Subtasks
                foreach ($subtask in $task.Subtasks) {
                    $data += $this.TaskToData($subtask)
                }
            }
            
            $json = ConvertTo-Json $data -Depth 10
            
            # Atomic save: write to temp file first
            $tempFile = "$($this.DataFile).tmp"
            
            # Create backup before save
            if (Test-Path $this.DataFile) {
                $backupDir = Join-Path (Split-Path $this.DataFile -Parent) "backups"
                if (-not (Test-Path $backupDir)) {
                    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
                }
                
                $timestamp = [datetime]::Now.ToString("yyyyMMdd_HHmmss")
                $backupFile = Join-Path $backupDir "tasks_backup_$timestamp.json"
                Copy-Item -Path $this.DataFile -Destination $backupFile -Force
                
                # Keep only last 10 backups
                $backups = Get-ChildItem -Path $backupDir -Filter "tasks_backup_*.json" | 
                           Sort-Object -Property CreationTime -Descending
                if ($backups.Count -gt 10) {
                    $backups | Select-Object -Skip 10 | Remove-Item -Force
                }
            }
            
            # Write to temp file
            [System.IO.File]::WriteAllText($tempFile, $json)
            
            # Atomic rename
            Move-Item -Path $tempFile -Destination $this.DataFile -Force
        } catch {
            # Clean up temp file if it exists
            if (Test-Path "$($this.DataFile).tmp") {
                Remove-Item -Path "$($this.DataFile).tmp" -Force -ErrorAction SilentlyContinue
            }
            Write-Warning "Failed to save tasks: $_"
        }
    }
    
    [hashtable] TaskToData([SimpleTask]$task) {
        return @{
            Id = $task.Id
            Title = $task.Title
            Completed = $task.Completed
            Priority = $task.Priority
            Notes = $task.Notes
            ParentId = $task.ParentId
            SubtasksCollapsed = $task.SubtasksCollapsed
            ColorTheme = $task.ColorTheme
            SubtaskColorTheme = $task.SubtaskColorTheme
            SortOrder = $task.SortOrder
            Tags = $task.Tags
            DueDate = if ($task.DueDate -ne [datetime]::MinValue) { $task.DueDate.ToString("o") } else { $null }
            CreatedDate = $task.CreatedDate.ToString("o")
            ModifiedDate = $task.ModifiedDate.ToString("o")
        }
    }
    
    [void] CreateSampleTasks() {
        $this.Tasks.Clear()
        
        # Task 1 with subtasks (Work theme)
        $task1 = [SimpleTask]::new("Complete quarterly report")
        $task1.Priority = "High"
        $task1.DueDate = (Get-Date).AddDays(3)
        $task1.ColorTheme = "work"
        $task1.SubtaskColorTheme = "work"
        $task1.SortOrder = 1
        $task1.Tags = @("work", "finance", "quarterly", "deadline")
        $task1.Notes = "# Quarterly Report`n`n## Overview`nQ4 2024 financial report for board meeting.`n`n## Key Metrics`n- Revenue: Up 15%`n- Costs: Down 5%`n- Profit margin: 22%`n`n## Action Items`n1. Compile sales data`n2. Review expense reports`n3. Create projections"
        
        $subtask1 = [SimpleTask]::new("Revenue analysis")
        $subtask2 = [SimpleTask]::new("Cost breakdown")
        $subtask3 = [SimpleTask]::new("Future projections")
        
        $task1.AddSubtask($subtask1)
        $task1.AddSubtask($subtask2)
        $task1.AddSubtask($subtask3)
        
        $this.Tasks.Add($task1)
        
        # Task 2 with subtask (Urgent theme)
        $task2 = [SimpleTask]::new("Review code changes")
        $task2.Priority = "Medium"
        $task2.DueDate = (Get-Date).AddDays(1)
        $task2.ColorTheme = "urgent"
        $task2.SubtaskColorTheme = "urgent"
        $task2.SortOrder = 2
        $task2.Tags = @("urgent", "code-review", "security", "backend")
        $task2.Notes = "Review PR #142`n`nFocus areas:`n- Security implications`n- Performance impact`n- Code style"
        
        $subtask4 = [SimpleTask]::new("Check security vulnerabilities")
        $task2.AddSubtask($subtask4)
        
        $this.Tasks.Add($task2)
        
        # Task 3 (Personal theme)
        $task3 = [SimpleTask]::new("Team meeting preparation")
        $task3.Priority = "High"
        $task3.DueDate = (Get-Date).Date
        $task3.ColorTheme = "personal"
        $task3.SubtaskColorTheme = "personal"
        $task3.SortOrder = 3
        $task3.Completed = $true
        $task3.Notes = "Weekly team sync agenda"
        
        $this.Tasks.Add($task3)
        
        # Task 4 (Project theme)
        $task4 = [SimpleTask]::new("Update documentation")
        $task4.Priority = "Low"
        $task4.ColorTheme = "project"
        $task4.SubtaskColorTheme = "project"
        $task4.SortOrder = 4
        $task4.Tags = @("documentation", "api", "v2", "low-priority")
        $task4.Notes = "API docs need updating for v2.0"
        
        $this.Tasks.Add($task4)
        
        $this.Save()
    }
    
    [SimpleTask[]] GetParentTasks() {
        # Return tasks in their current order (preserves manual reordering)
        # Completed tasks are shown in place, not moved to bottom
        return $this.Tasks
    }
    
    [SimpleTask] GetTask([string]$id) {
        # Check parent tasks
        foreach ($task in $this.Tasks) {
            if ($task.Id -eq $id) {
                return $task
            }
            # Check subtasks
            foreach ($subtask in $task.Subtasks) {
                if ($subtask.Id -eq $id) {
                    return $subtask
                }
            }
        }
        return $null
    }
    
    [SimpleTask] GetParentTask([string]$taskId) {
        $task = $this.GetTask($taskId)
        if (-not $task) { return $null }
        
        if ($task.IsParent()) {
            return $task
        } else {
            return $this.GetTask($task.ParentId)
        }
    }
    
    [void] AddTask([SimpleTask]$task) {
        $task.ModifiedDate = Get-Date
        $this.Tasks.Add($task)
        $this.Save()
    }
    
    [void] AddSubtask([string]$parentId, [SimpleTask]$subtask) {
        $parent = $this.GetTask($parentId)
        if ($parent -and $parent.IsParent()) {
            $parent.AddSubtask($subtask)
            $parent.ModifiedDate = Get-Date
            $this.Save()
        }
    }
    
    [void] UpdateTask([SimpleTask]$task) {
        $task.ModifiedDate = Get-Date
        $this.Save()
    }
    
    [void] DeleteTask([string]$id) {
        $task = $this.GetTask($id)
        if (-not $task) { return }
        
        if ($task.IsParent()) {
            # Remove parent and all subtasks
            $this.Tasks.Remove($task)
        } else {
            # Remove subtask from parent
            $parent = $this.GetTask($task.ParentId)
            if ($parent) {
                $parent.Subtasks.Remove($task)
            }
        }
        
        $this.Save()
    }
    
    [void] ToggleComplete([string]$id) {
        $task = $this.GetTask($id)
        if ($task) {
            $task.Completed = -not $task.Completed
            $task.ModifiedDate = Get-Date
            
            # If parent task, toggle all subtasks
            if ($task.IsParent() -and $task.Completed) {
                foreach ($subtask in $task.Subtasks) {
                    $subtask.Completed = $true
                }
            }
            
            $this.Save()
        }
    }
    
    [void] MoveTaskUp([string]$id) {
        $task = $this.GetTask($id)
        if (-not $task) { 
            if ($global:Debug) { Write-Host "Task not found: $id" -ForegroundColor Red }
            return 
        }
        
        if ($task.IsParent()) {
            # Move parent task up in the main list
            $currentIndex = $this.Tasks.IndexOf($task)
            if ($global:Debug) { Write-Host "Moving parent task up from index $currentIndex" -ForegroundColor Yellow }
            if ($currentIndex -gt 0) {
                $this.Tasks.RemoveAt($currentIndex)
                $this.Tasks.Insert($currentIndex - 1, $task)
                $this.Save()
                if ($global:Debug) { Write-Host "Parent task moved to index $($currentIndex - 1)" -ForegroundColor Green }
            } else {
                if ($global:Debug) { Write-Host "Parent task already at top, cannot move up" -ForegroundColor Yellow }
            }
        } else {
            # Move subtask up within parent
            $parent = $this.GetTask($task.ParentId)
            if ($parent) {
                $currentIndex = $parent.Subtasks.IndexOf($task)
                if ($global:Debug) { Write-Host "Moving subtask up from index $currentIndex" -ForegroundColor Yellow }
                if ($currentIndex -gt 0) {
                    $parent.Subtasks.RemoveAt($currentIndex)
                    $parent.Subtasks.Insert($currentIndex - 1, $task)
                    $this.Save()
                    if ($global:Debug) { Write-Host "Subtask moved to index $($currentIndex - 1)" -ForegroundColor Green }
                } else {
                    if ($global:Debug) { Write-Host "Subtask already at top, cannot move up" -ForegroundColor Yellow }
                }
            } else {
                if ($global:Debug) { Write-Host "Parent task not found for subtask" -ForegroundColor Red }
            }
        }
    }
    
    [void] MoveTaskDown([string]$id) {
        $task = $this.GetTask($id)
        if (-not $task) { 
            if ($global:Debug) { Write-Host "Task not found: $id" -ForegroundColor Red }
            return 
        }
        
        if ($task.IsParent()) {
            # Move parent task down in the main list
            $currentIndex = $this.Tasks.IndexOf($task)
            if ($global:Debug) { Write-Host "Moving parent task down from index $currentIndex (max: $($this.Tasks.Count - 1))" -ForegroundColor Yellow }
            if ($currentIndex -ge 0 -and $currentIndex -lt ($this.Tasks.Count - 1)) {
                $this.Tasks.RemoveAt($currentIndex)
                $this.Tasks.Insert($currentIndex + 1, $task)
                $this.Save()
                if ($global:Debug) { Write-Host "Parent task moved to index $($currentIndex + 1)" -ForegroundColor Green }
            } else {
                if ($global:Debug) { Write-Host "Parent task already at bottom, cannot move down" -ForegroundColor Yellow }
            }
        } else {
            # Move subtask down within parent
            $parent = $this.GetTask($task.ParentId)
            if ($parent) {
                $currentIndex = $parent.Subtasks.IndexOf($task)
                if ($global:Debug) { Write-Host "Moving subtask down from index $currentIndex (max: $($parent.Subtasks.Count - 1))" -ForegroundColor Yellow }
                if ($currentIndex -ge 0 -and $currentIndex -lt ($parent.Subtasks.Count - 1)) {
                    $parent.Subtasks.RemoveAt($currentIndex)
                    $parent.Subtasks.Insert($currentIndex + 1, $task)
                    $this.Save()
                    if ($global:Debug) { Write-Host "Subtask moved to index $($currentIndex + 1)" -ForegroundColor Green }
                } else {
                    if ($global:Debug) { Write-Host "Subtask already at bottom, cannot move down" -ForegroundColor Yellow }
                }
            } else {
                if ($global:Debug) { Write-Host "Parent task not found for subtask" -ForegroundColor Red }
            }
        }
    }
}
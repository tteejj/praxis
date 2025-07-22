# TaskService.ps1 - Service for managing tasks

class TaskService {
    [System.Collections.Generic.List[Task]]$Tasks
    hidden [string]$DataPath
    hidden [bool]$_isDirty = $false
    
    TaskService() {
        $this.Tasks = [System.Collections.Generic.List[Task]]::new()
        
        # Set data path
        $dataDir = Join-Path $global:PraxisRoot "_ProjectData"
        $this.DataPath = Join-Path $dataDir "tasks.json"
        
        # Load existing tasks
        $this.Load()
    }
    
    # CRUD Operations
    [Task] AddTask([string]$title, [string]$projectId) {
        $task = [Task]::new()
        $task.Title = $title
        $task.ProjectId = $projectId
        
        $this.Tasks.Add($task)
        $this._isDirty = $true
        $this.Save()
        
        return $task
    }
    
    [Task] CreateTask([hashtable]$properties) {
        $task = [Task]::new()
        
        # Set properties from hashtable
        foreach ($key in $properties.Keys) {
            if ($task.PSObject.Properties.Name -contains $key) {
                $task.$key = $properties[$key]
            }
        }
        
        $this.Tasks.Add($task)
        $this._isDirty = $true
        $this.Save()
        
        return $task
    }
    
    [Task] GetTask([string]$id) {
        return $this.Tasks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    }
    
    [Task[]] GetAllTasks() {
        return $this.Tasks.ToArray()
    }
    
    [Task[]] GetTasksByProject([string]$projectId) {
        return $this.Tasks | Where-Object { $_.ProjectId -eq $projectId -and -not $_.Deleted }
    }
    
    [Task[]] GetActiveTasks() {
        return $this.Tasks | Where-Object { 
            -not $_.Deleted -and 
            $_.Status -ne [TaskStatus]::Completed -and 
            $_.Status -ne [TaskStatus]::Cancelled 
        }
    }
    
    [void] UpdateTask([Task]$task) {
        $task.UpdatedAt = Get-Date
        $this._isDirty = $true
        $this.Save()
    }
    
    [void] DeleteTask([string]$id) {
        $task = $this.GetTask($id)
        if ($task) {
            $task.Deleted = $true
            $task.UpdatedAt = Get-Date
            $this._isDirty = $true
            $this.Save()
        }
    }
    
    # Status management
    [void] UpdateTaskStatus([string]$id, [TaskStatus]$status) {
        $task = $this.GetTask($id)
        if ($task) {
            $task.Status = $status
            $task.UpdatedAt = Get-Date
            
            # Auto-update progress
            if ($status -eq [TaskStatus]::Completed) {
                $task.Progress = 100
            } elseif ($status -eq [TaskStatus]::Pending) {
                $task.Progress = 0
            }
            
            $this._isDirty = $true
            $this.Save()
        }
    }
    
    # Priority management
    [void] CyclePriority([string]$id) {
        $task = $this.GetTask($id)
        if ($task) {
            switch ($task.Priority) {
                ([TaskPriority]::Low) { $task.Priority = [TaskPriority]::Medium }
                ([TaskPriority]::Medium) { $task.Priority = [TaskPriority]::High }
                ([TaskPriority]::High) { $task.Priority = [TaskPriority]::Low }
            }
            $task.UpdatedAt = Get-Date
            $this._isDirty = $true
            $this.Save()
        }
    }
    
    # Persistence
    [void] Save() {
        if (-not $this._isDirty) { return }
        
        try {
            $json = $this.Tasks | ConvertTo-Json -Depth 10
            $json | Set-Content -Path $this.DataPath -Encoding UTF8
            $this._isDirty = $false
            
            if ($global:Logger) {
                $global:Logger.Debug("TaskService: Saved $($this.Tasks.Count) tasks")
            }
        } catch {
            if ($global:Logger) {
                $global:Logger.Error("TaskService: Failed to save tasks: $_")
            }
        }
    }
    
    [void] Load() {
        if (Test-Path $this.DataPath) {
            try {
                $json = Get-Content -Path $this.DataPath -Raw
                $data = $json | ConvertFrom-Json
                
                $this.Tasks.Clear()
                foreach ($item in $data) {
                    $task = [Task]::new()
                    
                    # Map properties
                    $task.Id = $item.Id
                    $task.Title = $item.Title
                    $task.Description = $item.Description
                    $task.Status = [TaskStatus]$item.Status
                    $task.Priority = [TaskPriority]$item.Priority
                    $task.Progress = $item.Progress
                    $task.ProjectId = $item.ProjectId
                    $task.Tags = $item.Tags
                    $task.DueDate = if ($item.DueDate) { [DateTime]$item.DueDate } else { [DateTime]::MinValue }
                    $task.CreatedAt = [DateTime]$item.CreatedAt
                    $task.UpdatedAt = [DateTime]$item.UpdatedAt
                    $task.Deleted = $item.Deleted
                    
                    $this.Tasks.Add($task)
                }
                
                if ($global:Logger) {
                    $global:Logger.Debug("TaskService: Loaded $($this.Tasks.Count) tasks")
                }
            } catch {
                if ($global:Logger) {
                    $global:Logger.Error("TaskService: Failed to load tasks: $_")
                }
                # Start with empty list on error
                $this.Tasks.Clear()
            }
        } else {
            # Create sample tasks for testing
            $this.CreateSampleTasks()
        }
    }
    
    hidden [void] CreateSampleTasks() {
        # Create a few sample tasks
        $task1 = $this.AddTask("Implement user authentication", "")
        $task1.Description = "Add login/logout functionality with session management"
        $task1.Priority = [TaskPriority]::High
        $task1.Status = [TaskStatus]::InProgress
        $task1.Progress = 45
        
        $task2 = $this.AddTask("Write API documentation", "")
        $task2.Description = "Document all REST endpoints with examples"
        $task2.Priority = [TaskPriority]::Medium
        $task2.DueDate = (Get-Date).AddDays(7)
        
        $task3 = $this.AddTask("Fix navigation bug", "")
        $task3.Description = "Users report navigation not working after login"
        $task3.Priority = [TaskPriority]::High
        $task3.Status = [TaskStatus]::Completed
        $task3.Progress = 100
        
        $this.Save()
    }
}
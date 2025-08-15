# Services/SimpleTaskService.ps1 - Task data service with CRUD operations
# Matches the actual SimpleTaskService interface from your codebase

. "$PSScriptRoot/../Models/SimpleTask.ps1"

class SimpleTaskService {
    [string]$DataPath = "Data/tasks.json"
    [SimpleTask[]]$AllTasks = @()
    [hashtable]$TaskLookup = @{}  # Id -> Task for performance
    [bool]$IsLoaded = $false
    
    SimpleTaskService() {
        $this.LoadTasks()
    }
    
    SimpleTaskService([string]$dataPath) {
        $this.DataPath = $dataPath
        $this.LoadTasks()
    }
    
    # === CORE DATA OPERATIONS ===
    
    [void] LoadTasks() {
        try {
            if (-not (Test-Path $this.DataPath)) {
                Write-Host "Tasks file not found: $($this.DataPath), creating sample data" -ForegroundColor Yellow
                $this.CreateSampleTasks()
                $this.SaveTasks()
                return
            }
            
            $json = Get-Content $this.DataPath -Raw
            if ([string]::IsNullOrWhiteSpace($json)) {
                Write-Host "Tasks file is empty, creating sample data" -ForegroundColor Yellow
                $this.CreateSampleTasks()
                $this.SaveTasks()
                return
            }
            
            $taskData = $json | ConvertFrom-Json
            $this.AllTasks = @()
            $this.TaskLookup = @{}
            
            foreach ($taskJson in $taskData) {
                $task = $this.ConvertFromJson($taskJson)
                $this.AllTasks += $task
                $this.TaskLookup[$task.Id] = $task
            }
            
            $this.IsLoaded = $true
            Write-Host "Loaded $($this.AllTasks.Count) tasks from $($this.DataPath)" -ForegroundColor Green
            
        } catch {
            Write-Host "Error loading tasks: $($_.Exception.Message)" -ForegroundColor Red
            $this.CreateSampleTasks()
        }
    }
    
    [void] SaveTasks() {
        try {
            # Ensure directory exists
            $dir = Split-Path $this.DataPath -Parent
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            
            # Convert tasks to JSON
            $taskData = @()
            foreach ($task in $this.AllTasks) {
                $taskData += $this.ConvertToJson($task)
            }
            
            $json = $taskData | ConvertTo-Json -Depth 10
            Set-Content -Path $this.DataPath -Value $json -Encoding UTF8
            
            Write-Host "Saved $($this.AllTasks.Count) tasks to $($this.DataPath)" -ForegroundColor Green
            
        } catch {
            Write-Host "Error saving tasks: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }
    
    # === TASK CRUD OPERATIONS ===
    
    [SimpleTask[]] GetAllTasks() {
        return $this.AllTasks
    }
    
    [SimpleTask[]] GetParentTasks() {
        return $this.AllTasks | Where-Object { $_.IsParent() }
    }
    
    [SimpleTask] GetTaskById([string]$taskId) {
        if ($this.TaskLookup.ContainsKey($taskId)) {
            return $this.TaskLookup[$taskId]
        }
        return $null
    }
    
    [SimpleTask[]] GetSubtasks([string]$parentId) {
        $parent = $this.GetTaskById($parentId)
        if ($parent) {
            return $parent.Subtasks
        }
        return @()
    }
    
    [void] AddTask([SimpleTask]$task) {
        # Ensure unique ID
        if ([string]::IsNullOrEmpty($task.Id)) {
            $task.Id = [System.Guid]::NewGuid().ToString()
        }
        
        # Check for duplicates
        if ($this.TaskLookup.ContainsKey($task.Id)) {
            throw "Task with ID $($task.Id) already exists"
        }
        
        $task.CreatedDate = [DateTime]::Now
        $task.ModifiedDate = [DateTime]::Now
        
        $this.AllTasks += $task
        $this.TaskLookup[$task.Id] = $task
        
        Write-Host "Added task: $($task.Title)" -ForegroundColor Green
    }
    
    [void] SaveTask([SimpleTask]$task) {
        if (-not $this.TaskLookup.ContainsKey($task.Id)) {
            # New task
            $this.AddTask($task)
        } else {
            # Update existing task
            $task.ModifiedDate = [DateTime]::Now
            $this.TaskLookup[$task.Id] = $task
            
            # Update in AllTasks array
            for ($i = 0; $i -lt $this.AllTasks.Count; $i++) {
                if ($this.AllTasks[$i].Id -eq $task.Id) {
                    $this.AllTasks[$i] = $task
                    break
                }
            }
            
            Write-Host "Updated task: $($task.Title)" -ForegroundColor Green
        }
    }
    
    [bool] DeleteTask([string]$taskId) {
        $task = $this.GetTaskById($taskId)
        if (-not $task) {
            Write-Host "Task not found: $taskId" -ForegroundColor Yellow
            return $false
        }
        
        # Remove from parent if it's a subtask
        if (-not $task.IsParent()) {
            $parent = $this.GetTaskById($task.ParentId)
            if ($parent) {
                $parent.Subtasks = $parent.Subtasks | Where-Object { $_.Id -ne $taskId }
                $parent.ModifiedDate = [DateTime]::Now
            }
        } else {
            # Remove all subtasks if it's a parent
            foreach ($subtask in $task.Subtasks) {
                $this.TaskLookup.Remove($subtask.Id)
            }
        }
        
        # Remove from main collections
        $this.AllTasks = $this.AllTasks | Where-Object { $_.Id -ne $taskId }
        $this.TaskLookup.Remove($taskId)
        
        Write-Host "Deleted task: $($task.Title)" -ForegroundColor Green
        return $true
    }
    
    [void] ToggleComplete([string]$taskId) {
        $task = $this.GetTaskById($taskId)
        if ($task) {
            $task.Completed = -not $task.Completed
            $task.ModifiedDate = [DateTime]::Now
            
            $status = if ($task.Completed) { "completed" } else { "incomplete" }
            Write-Host "Task '$($task.Title)' marked as $status" -ForegroundColor Green
        }
    }
    
    [void] AddSubtask([string]$parentId, [SimpleTask]$subtask) {
        $parent = $this.GetTaskById($parentId)
        if (-not $parent) {
            throw "Parent task not found: $parentId"
        }
        
        if (-not $parent.IsParent()) {
            throw "Cannot add subtask to subtask"
        }
        
        $subtask.ParentId = $parentId
        $subtask.CreatedDate = [DateTime]::Now
        $subtask.ModifiedDate = [DateTime]::Now
        
        if ([string]::IsNullOrEmpty($subtask.Id)) {
            $subtask.Id = [System.Guid]::NewGuid().ToString()
        }
        
        $parent.AddSubtask($subtask)
        $parent.ModifiedDate = [DateTime]::Now
        $this.TaskLookup[$subtask.Id] = $subtask
        
        Write-Host "Added subtask '$($subtask.Title)' to '$($parent.Title)'" -ForegroundColor Green
    }
    
    # === FILTERING & SEARCH ===
    
    [SimpleTask[]] GetTasksByFilter([string]$filter) {
        $tasks = $this.GetParentTasks()
        
        switch ($filter) {
            "All" { return $tasks }
            "Today" { return $tasks | Where-Object { $_.IsDueToday() } }
            "High" { return $tasks | Where-Object { $_.Priority -eq "High" } }
            "Medium" { return $tasks | Where-Object { $_.Priority -eq "Medium" } }
            "Low" { return $tasks | Where-Object { $_.Priority -eq "Low" } }
            "Completed" { return $tasks | Where-Object { $_.Completed } }
            "Pending" { return $tasks | Where-Object { -not $_.Completed } }
            default { return $tasks }
        }
        return $tasks
    }
    
    [SimpleTask[]] SearchTasks([string]$searchTerm) {
        if ([string]::IsNullOrEmpty($searchTerm)) {
            return $this.GetParentTasks()
        }
        
        return $this.GetParentTasks() | Where-Object { $_.MatchesSearch($searchTerm) }
    }
    
    [SimpleTask[]] GetTasksByTag([string]$tag) {
        if ([string]::IsNullOrEmpty($tag)) {
            return $this.GetParentTasks()
        }
        
        return $this.GetParentTasks() | Where-Object { $_.MatchesTag($tag) }
    }
    
    # === SAMPLE DATA ===
    
    [void] CreateSampleTasks() {
        $this.AllTasks = @()
        $this.TaskLookup = @{}
        
        # Sample parent tasks
        $task1 = [SimpleTask]::new("Review quarterly reports")
        $task1.Priority = "High"
        $task1.DueDate = (Get-Date).AddDays(2)
        $task1.Tags = @("reports", "quarterly", "urgent")
        $task1.ID1 = "RPT"
        $task1.ID2 = "RPT001"
        
        $task2 = [SimpleTask]::new("Update documentation")
        $task2.Priority = "Medium"
        $task2.DueDate = (Get-Date).AddDays(7)
        $task2.Tags = @("docs", "maintenance")
        $task2.ID1 = "DOC"
        $task2.ID2 = "DOC001"
        
        $task3 = [SimpleTask]::new("Plan team meeting")
        $task3.Priority = "Today"
        $task3.DueDate = Get-Date
        $task3.Tags = @("meeting", "planning")
        $task3.ID1 = "MTG"
        $task3.ID2 = "MTG001"
        
        # Add subtasks
        $subtask1 = [SimpleTask]::new("Review Q1 numbers")
        $subtask1.Priority = "High"
        $task1.AddSubtask($subtask1)
        
        $subtask2 = [SimpleTask]::new("Compare with projections")
        $subtask2.Priority = "Medium"
        $task1.AddSubtask($subtask2)
        
        $subtask3 = [SimpleTask]::new("Update API documentation")
        $subtask3.Priority = "Medium"
        $task2.AddSubtask($subtask3)
        
        # Add to service
        $this.AddTask($task1)
        $this.AddTask($task2)
        $this.AddTask($task3)
        
        # Add subtasks to lookup
        $this.TaskLookup[$subtask1.Id] = $subtask1
        $this.TaskLookup[$subtask2.Id] = $subtask2
        $this.TaskLookup[$subtask3.Id] = $subtask3
    }
    
    # === JSON CONVERSION ===
    
    [object] ConvertToJson([SimpleTask]$task) {
        $taskObj = @{
            Id = $task.Id
            Title = $task.Title
            Completed = $task.Completed
            CreatedDate = $task.CreatedDate.ToString("yyyy-MM-ddTHH:mm:ss")
            ModifiedDate = $task.ModifiedDate.ToString("yyyy-MM-ddTHH:mm:ss")
            Priority = $task.Priority
            Tags = $task.Tags
            Notes = $task.Notes
            ID1 = $task.ID1
            ID2 = $task.ID2
            ParentId = $task.ParentId
            SubtasksCollapsed = $task.SubtasksCollapsed
            SortOrder = $task.SortOrder
            ProjectFolderPath = $task.ProjectFolderPath
            T2020CallLogFile = $task.T2020CallLogFile
            ExportDataFile = $task.ExportDataFile
            ActionLogName = $task.ActionLogName
            Subtasks = @()
        }
        
        if ($task.DueDate -ne [DateTime]::MinValue) {
            $taskObj.DueDate = $task.DueDate.ToString("yyyy-MM-ddTHH:mm:ss")
        }
        
        foreach ($subtask in $task.Subtasks) {
            $taskObj.Subtasks += $this.ConvertToJson($subtask)
        }
        
        return $taskObj
    }
    
    [SimpleTask] ConvertFromJson([object]$taskObj) {
        $task = [SimpleTask]::new()
        $task.Id = $taskObj.Id
        $task.Title = $taskObj.Title
        $task.Completed = $taskObj.Completed
        $task.CreatedDate = [DateTime]::Parse($taskObj.CreatedDate)
        $task.ModifiedDate = [DateTime]::Parse($taskObj.ModifiedDate)
        $task.Priority = $taskObj.Priority
        $task.Tags = $taskObj.Tags
        $task.Notes = $taskObj.Notes
        $task.ID1 = $taskObj.ID1
        $task.ID2 = $taskObj.ID2
        $task.ParentId = $taskObj.ParentId
        $task.SubtasksCollapsed = $taskObj.SubtasksCollapsed
        $task.SortOrder = $taskObj.SortOrder
        $task.ProjectFolderPath = $taskObj.ProjectFolderPath
        $task.T2020CallLogFile = $taskObj.T2020CallLogFile
        $task.ExportDataFile = $taskObj.ExportDataFile
        $task.ActionLogName = $taskObj.ActionLogName
        
        if ($taskObj.DueDate) {
            $task.DueDate = [DateTime]::Parse($taskObj.DueDate)
        }
        
        foreach ($subtaskObj in $taskObj.Subtasks) {
            $subtask = $this.ConvertFromJson($subtaskObj)
            $task.AddSubtask($subtask)
        }
        
        return $task
    }
    
    # === UTILITY METHODS ===
    
    [int] GetTaskCount() {
        return $this.AllTasks.Count
    }
    
    [int] GetCompletedTaskCount() {
        return ($this.AllTasks | Where-Object { $_.Completed }).Count
    }
    
    [int] GetPendingTaskCount() {
        return ($this.AllTasks | Where-Object { -not $_.Completed }).Count
    }
    
    [void] PrintStats() {
        Write-Host "=== Task Statistics ===" -ForegroundColor Cyan
        Write-Host "Total Tasks: $($this.GetTaskCount())" -ForegroundColor White
        Write-Host "Completed: $($this.GetCompletedTaskCount())" -ForegroundColor Green
        Write-Host "Pending: $($this.GetPendingTaskCount())" -ForegroundColor Yellow
        Write-Host "Parent Tasks: $($this.GetParentTasks().Count)" -ForegroundColor Blue
    }
}
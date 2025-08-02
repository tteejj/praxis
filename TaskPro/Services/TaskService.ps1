# TaskService.ps1 - Simple task storage service

class TaskService {
    [string]$DataFile
    [System.Collections.Generic.List[Task]]$Tasks
    
    TaskService() {
        $this.DataFile = Join-Path $PSScriptRoot "../Data/tasks.json"
        $this.Tasks = [System.Collections.Generic.List[Task]]::new()
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
                foreach ($taskData in $data) {
                    $task = [Task]::new()
                    $task.Id = $taskData.Id
                    $task.Title = $taskData.Title
                    $task.Completed = $taskData.Completed
                    $task.Priority = $taskData.Priority
                    $task.Project = $taskData.Project
                    $task.Notes = $taskData.Notes
                    
                    if ($taskData.DueDate) {
                        $task.DueDate = [datetime]::Parse($taskData.DueDate)
                    }
                    if ($taskData.CreatedDate) {
                        $task.CreatedDate = [datetime]::Parse($taskData.CreatedDate)
                    }
                    if ($taskData.ModifiedDate) {
                        $task.ModifiedDate = [datetime]::Parse($taskData.ModifiedDate)
                    }
                    
                    $this.Tasks.Add($task)
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
            foreach ($task in $this.Tasks) {
                $data += @{
                    Id = $task.Id
                    Title = $task.Title
                    Completed = $task.Completed
                    Priority = $task.Priority
                    Project = $task.Project
                    Notes = $task.Notes
                    DueDate = if ($task.DueDate -ne [datetime]::MinValue) { $task.DueDate.ToString("o") } else { $null }
                    CreatedDate = $task.CreatedDate.ToString("o")
                    ModifiedDate = $task.ModifiedDate.ToString("o")
                }
            }
            
            $json = ConvertTo-Json $data -Depth 10
            Set-Content -Path $this.DataFile -Value $json -Encoding UTF8
        } catch {
            Write-Warning "Failed to save tasks: $_"
        }
    }
    
    [void] CreateSampleTasks() {
        $this.Tasks.Clear()
        
        # Sample tasks
        $task1 = [Task]::new("Complete quarterly report")
        $task1.Priority = "High"
        $task1.Project = "Finance"
        $task1.DueDate = (Get-Date).AddDays(3)
        $task1.Notes = "# Quarterly Report`n`n## Key Points`n- Revenue analysis`n- Cost breakdown`n- Future projections`n`n## Data Sources`n- Sales database`n- Expense reports"
        $this.Tasks.Add($task1)
        
        $task2 = [Task]::new("Review code changes")
        $task2.Priority = "Medium"
        $task2.Project = "Development"
        $task2.DueDate = (Get-Date).AddDays(1)
        $task2.Notes = "Review PR #142 for the new authentication system.`n`nCheck for:`n- Security vulnerabilities`n- Code style compliance`n- Test coverage"
        $this.Tasks.Add($task2)
        
        $task3 = [Task]::new("Update documentation")
        $task3.Priority = "Low"
        $task3.Project = "Development"
        $task3.Notes = "Update API documentation for v2.0 release"
        $this.Tasks.Add($task3)
        
        $task4 = [Task]::new("Team meeting preparation")
        $task4.Priority = "High"
        $task4.DueDate = (Get-Date).Date
        $task4.Notes = "Agenda:`n1. Sprint review`n2. Blockers discussion`n3. Next sprint planning"
        $this.Tasks.Add($task4)
        
        $this.Save()
    }
    
    [Task[]] GetTasks() {
        return $this.Tasks.ToArray()
    }
    
    [Task[]] GetActiveTasks() {
        return $this.Tasks | Where-Object { -not $_.Completed } | Sort-Object DueDate, Priority
    }
    
    [Task] GetTask([string]$id) {
        return $this.Tasks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    }
    
    [void] AddTask([Task]$task) {
        $task.ModifiedDate = Get-Date
        $this.Tasks.Add($task)
        $this.Save()
    }
    
    [void] UpdateTask([Task]$task) {
        $task.ModifiedDate = Get-Date
        $this.Save()
    }
    
    [void] DeleteTask([string]$id) {
        $task = $this.GetTask($id)
        if ($task) {
            $this.Tasks.Remove($task)
            $this.Save()
        }
    }
    
    [void] ToggleComplete([string]$id) {
        $task = $this.GetTask($id)
        if ($task) {
            $task.Completed = -not $task.Completed
            $task.ModifiedDate = Get-Date
            $this.Save()
        }
    }
}
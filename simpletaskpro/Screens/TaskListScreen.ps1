# TaskListScreen.ps1 - Minimal Smart Component Implementation  
# Following plan_final.md - only essential task-specific functionality

class TaskListScreen : ListScreen {
    [SimpleTaskService]$TaskService
    [SimpleTask[]]$Tasks = @()
    
    # Editing properties for FastLineBuilder integration
    [SimpleTask]$EditingTask = $null
    [string]$EditingField = ""
    [int]$EditingIndex = -1
    [string]$EditingValue = ""

    TaskListScreen([ServiceContainer]$services) : base($services) { }
    
    [void] OnInitialize() {
        ([ListScreen]$this).OnInitialize()
        $this.TaskService = $this.Services.GetService("SimpleTaskService")
        $this.Title = "Tasks"
        $this.LoadData()
    }
    
    [void] LoadData() {
        if ($this.TaskService) {
            $this.Tasks = $this.TaskService.GetParentTasks()
            $this.BuildFlatList()
        }
    }
    
    [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
        $task = $item.Task
        $level = $item.Level
        $isLast = $item.IsLast
        
        $viewModel = $this.ContentBuilder.GenerateTaskViewModel($task, $this, $level, $isLast)
        # RenderEngine expects Text with [LINEBREAK] separator
        return ($viewModel -join "[LINEBREAK]")
    }
    
    [void] HandleDerivedCommand([string]$command) {
        switch ($command) {
            "action.new" { $this.CreateNewTask() }
            "action.delete" { $this.DeleteCurrentTask() } 
            "task.toggle.complete" { $this.ToggleComplete() }
        }
    }
    
    [void] BuildFlatList() {
        # Reuse existing FlatList to avoid object allocation
        $this.FlatList.Clear()
        
        foreach ($task in $this.Tasks) {
            $this.FlatList.Add(@{ Task = $task; Level = 0; IsLast = $false })
            
            foreach ($subtask in $task.Subtasks) {
                $this.FlatList.Add(@{ Task = $subtask; Level = 1; IsLast = $false })
            }
        }
    }
    
    [void] CreateNewTask() {
        $task = [SimpleTask]::new()
        $task.Title = "New Task"
        $task.CreatedDate = Get-Date
        $this.TaskService.AddTask($task)
        $this.LoadData()
    }
    
    [void] DeleteCurrentTask() {
        if ($this.FlatList.Count -gt 0) {
            $item = $this.FlatList[$this.SelectedIndex]
            $this.TaskService.DeleteTask($item.Task.Id)
            $this.LoadData()
        }
    }
    
    [void] ToggleComplete() {
        if ($this.FlatList.Count -gt 0) {
            $item = $this.FlatList[$this.SelectedIndex]
            $this.TaskService.ToggleComplete($item.Task.Id)
            $this.LoadData()
        }
    }
}
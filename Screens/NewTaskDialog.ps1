# NewTaskDialog.ps1 - Dialog for creating new tasks using UnifiedDialog

class NewTaskDialog : UnifiedDialog {
    [MinimalListBox]$PriorityList
    
    NewTaskDialog() : base("New Task", 50, 16) {
        # Add task fields using simplified UnifiedDialog API
        $this.AddField("title", "Task Title", "")
        $this.AddField("description", "Description", "")
        
        # Create priority list box manually for more control
        $this.PriorityList = [MinimalListBox]::new()
        $this.PriorityList.ShowBorder = $false
        $this.PriorityList.Height = 3
        $this.PriorityList.SetItems(@("Low", "Medium", "High"))
        $this.PriorityList.SelectedIndex = 1  # Default to Medium
        $this.PriorityList | Add-Member -NotePropertyName "FieldName" -NotePropertyValue "priority"
        $this.AddControl($this.PriorityList)
        
        # Set button labels
        $this.SetButtons("Create", "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.CreateTask() }.GetNewClosure()
    }
    
    [void] CreateTask() {
        # Get field values
        $title = $this.GetFieldValue("title")
        
        # Validate required fields
        if ([string]::IsNullOrWhiteSpace($title)) {
            # Show error - for now just return
            return
        }
        
        # Get selected priority
        $selectedPriority = $this.PriorityList.GetSelectedItem()
        $priority = switch ($selectedPriority) {
            "Low" { [TaskPriority]::Low }
            "High" { [TaskPriority]::High }
            default { [TaskPriority]::Medium }
        }
        
        $taskData = @{
            Title = $title.Trim()
            Description = $this.GetFieldValue("description").Trim()
            Priority = $priority
        }
        
        # Get task service and create task
        $taskService = $this.GetService("TaskService")
        if ($taskService) {
            try {
                $newTask = $taskService.CreateTask($taskData)
                
                # Manually refresh the tasks screen instead of using events
                # Find the TasksScreen by type name to avoid loading order issues
                if ($global:ScreenManager -and $global:ScreenManager.Screens.Count -gt 0) {
                    foreach ($screen in $global:ScreenManager.Screens) {
                        if ($screen.GetType().Name -eq "TasksScreen") {
                            $screen.LoadData()
                            break
                        }
                    }
                }
                
                # Close dialog
                $this.Close()
                
            } catch {
                # Handle error - for now just log
                if ($global:Logger) {
                    $global:Logger.Error("Failed to create task: $_")
                }
            }
        }
    }
}
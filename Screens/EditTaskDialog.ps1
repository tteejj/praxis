# EditTaskDialog.ps1 - Dialog for editing existing tasks using UnifiedDialog

class EditTaskDialog : UnifiedDialog {
    [Task]$Task
    [MinimalListBox]$StatusList
    [MinimalListBox]$PriorityList
    
    EditTaskDialog([Task]$task) : base("Edit Task", 60, 18) {
        $this.Task = $task
        
        # Add task fields using simplified UnifiedDialog API with current values
        $this.AddField("title", "Task Title", $task.Title)
        $this.AddField("description", "Description", $task.Description)
        $this.AddField("progress", "Progress (0-100)", $task.Progress.ToString())
        
        # Create status list box manually for more control
        $this.StatusList = [MinimalListBox]::new()
        $this.StatusList.ShowBorder = $false
        $this.StatusList.Height = 4
        $this.StatusList.SetItems(@(
            @{Name="Pending"; Value=[TaskStatus]::Pending},
            @{Name="In Progress"; Value=[TaskStatus]::InProgress},
            @{Name="Completed"; Value=[TaskStatus]::Completed},
            @{Name="Cancelled"; Value=[TaskStatus]::Cancelled}
        ))
        $this.StatusList.ItemFormatter = { param($item) $item.Name }
        # Select current status
        for ($i = 0; $i -lt $this.StatusList.Items.Count; $i++) {
            if ($this.StatusList.Items[$i].Value -eq $this.Task.Status) {
                $this.StatusList.SelectedIndex = $i
                break
            }
        }
        $this.StatusList | Add-Member -NotePropertyName "FieldName" -NotePropertyValue "status"
        $this.AddControl($this.StatusList)
        
        # Create priority list box manually for more control
        $this.PriorityList = [MinimalListBox]::new()
        $this.PriorityList.ShowBorder = $false
        $this.PriorityList.Height = 3
        $this.PriorityList.SetItems(@(
            @{Name="Low"; Value=[TaskPriority]::Low},
            @{Name="Medium"; Value=[TaskPriority]::Medium},
            @{Name="High"; Value=[TaskPriority]::High}
        ))
        $this.PriorityList.ItemFormatter = { param($item) $item.Name }
        # Select current priority
        for ($i = 0; $i -lt $this.PriorityList.Items.Count; $i++) {
            if ($this.PriorityList.Items[$i].Value -eq $this.Task.Priority) {
                $this.PriorityList.SelectedIndex = $i
                break
            }
        }
        $this.PriorityList | Add-Member -NotePropertyName "FieldName" -NotePropertyValue "priority"
        $this.AddControl($this.PriorityList)
        
        # Set button labels
        $this.SetButtons("Save", "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.SaveTask() }.GetNewClosure()
    }
    
    [void] SaveTask() {
        # Get field values
        $title = $this.GetFieldValue("title")
        
        # Validate required fields
        if ([string]::IsNullOrWhiteSpace($title)) {
            # Show error - for now just return
            return
        }
        
        # Get selected values
        $selectedStatus = $this.StatusList.GetSelectedItem()
        $selectedPriority = $this.PriorityList.GetSelectedItem()
        
        # Parse progress
        $progress = 0
        $progressText = $this.GetFieldValue("progress")
        if ([int]::TryParse($progressText, [ref]$progress)) {
            $progress = [Math]::Max(0, [Math]::Min(100, $progress))
        }
        
        # Update task properties
        $this.Task.Title = $title
        $this.Task.Description = $this.GetFieldValue("description")
        $this.Task.Status = if ($selectedStatus) { $selectedStatus.Value } else { $this.Task.Status }
        $this.Task.Priority = if ($selectedPriority) { $selectedPriority.Value } else { $this.Task.Priority }
        $this.Task.Progress = $progress
        $this.Task.UpdatedAt = [DateTime]::Now
        
        # Save via service
        $taskService = $this.GetService("TaskService")
        if ($taskService) {
            try {
                $taskService.UpdateTask($this.Task)
                
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
                    $global:Logger.Error("Failed to update task: $_")
                }
            }
        }
    }
}
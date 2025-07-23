# NewTaskDialog.ps1 - Dialog for creating new tasks (refactored to use BaseDialog)

class NewTaskDialog : BaseDialog {
    [TextBox]$TitleBox
    [TextBox]$DescriptionBox
    [ListBox]$PriorityList
    
    NewTaskDialog() : base("New Task", 50, 18) {
        $this.PrimaryButtonText = "Create"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] InitializeContent() {
        # Create title textbox
        $this.TitleBox = [TextBox]::new()
        $this.TitleBox.Placeholder = "Enter task title..."
        $this.AddContentControl($this.TitleBox, 1)
        
        # Create description textbox
        $this.DescriptionBox = [TextBox]::new()
        $this.DescriptionBox.Placeholder = "Enter description (optional)..."
        $this.AddContentControl($this.DescriptionBox, 2)
        
        # Create priority list
        $this.PriorityList = [ListBox]::new()
        $this.PriorityList.Title = "Priority"
        $this.PriorityList.ShowBorder = $true
        $this.PriorityList.SetItems(@("Low", "Medium", "High"))
        $this.PriorityList.SelectIndex(1)  # Default to Medium
        $this.AddContentControl($this.PriorityList, 3)
        
        # Set up primary action
        $dialog = $this
        $this.OnPrimary = {
            if ($dialog.TitleBox.Text.Trim()) {
                # Get selected priority
                $selectedPriority = $dialog.PriorityList.GetSelectedItem()
                $priority = switch ($selectedPriority) {
                    "Low" { [TaskPriority]::Low }
                    "High" { [TaskPriority]::High }
                    default { [TaskPriority]::Medium }
                }
                
                $taskData = @{
                    Title = $dialog.TitleBox.Text.Trim()
                    Description = $dialog.DescriptionBox.Text.Trim()
                    Priority = $priority
                }
                
                # Use EventBus if available
                if ($dialog.EventBus) {
                    # Create task via service
                    $taskService = $global:ServiceContainer.GetService("TaskService")
                    if ($taskService) {
                        $newTask = $taskService.CreateTask($taskData)
                        
                        # Publish event
                        $dialog.EventBus.Publish([EventNames]::TaskCreated, @{ 
                            Task = $newTask 
                        })
                    }
                    
                    # Publish dialog closed event
                    $dialog.EventBus.Publish([EventNames]::DialogClosed, @{ 
                        Dialog = 'NewTaskDialog'
                        Action = 'Create'
                        Data = $taskData
                    })
                } else {
                    # Legacy callback support
                    if ($dialog.OnCreate -and $dialog.OnCreate.GetType().Name -eq 'ScriptBlock') {
                        & $dialog.OnCreate $taskData
                    }
                }
            }
        }.GetNewClosure()
        
        # Set up secondary action
        $this.OnSecondary = {
            # Publish dialog closed event
            if ($dialog.EventBus) {
                $dialog.EventBus.Publish([EventNames]::DialogClosed, @{ 
                    Dialog = 'NewTaskDialog'
                    Action = 'Cancel'
                })
            } else {
                # Legacy callback support
                if ($dialog.OnCancel -and $dialog.OnCancel.GetType().Name -eq 'ScriptBlock') {
                    & $dialog.OnCancel
                }
            }
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Custom positioning for task dialog controls
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        
        # Title box
        $this.TitleBox.SetBounds(
            $dialogX + $this.DialogPadding, 
            $dialogY + 2, 
            $controlWidth, 
            3
        )
        
        # Description box
        $this.DescriptionBox.SetBounds(
            $dialogX + $this.DialogPadding, 
            $dialogY + 6, 
            $controlWidth, 
            3
        )
        
        # Priority list
        $this.PriorityList.SetBounds(
            $dialogX + $this.DialogPadding, 
            $dialogY + 10, 
            $controlWidth, 
            5
        )
    }
}
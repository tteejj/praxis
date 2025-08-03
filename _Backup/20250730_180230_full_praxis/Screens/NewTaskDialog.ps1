# NewTaskDialog.ps1 - Dialog for creating new tasks (refactored to use BaseDialog)

class NewTaskDialog : BaseDialog {
    [MinimalTextBox]$TitleBox
    [MinimalTextBox]$DescriptionBox
    [MinimalListBox]$PriorityList
    
    NewTaskDialog() : base("New Task", 50, 20) {
        $this.PrimaryButtonText = "Create"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] InitializeContent() {
        # Create title section with label
        $this.AddContentLabel("Task Title:", 1)
        $this.TitleBox = [MinimalTextBox]::new()
        $this.TitleBox.Placeholder = "Enter task title..."
        $this.TitleBox.ShowBorder = $true
        $this.TitleBox.Height = 3  # Standard height for textbox
        $this.AddContentControl($this.TitleBox, 1)
        
        # Create description section with label  
        $this.AddContentLabel("Description (optional):", 2)
        $this.DescriptionBox = [MinimalTextBox]::new()
        $this.DescriptionBox.Placeholder = "Enter description..."
        $this.DescriptionBox.ShowBorder = $true
        $this.DescriptionBox.Height = 3  # Standard height for textbox
        $this.AddContentControl($this.DescriptionBox, 2)
        
        # Create priority section with label
        $this.AddContentLabel("Priority:", 3)
        $this.PriorityList = [MinimalListBox]::new()
        $this.PriorityList.ShowBorder = $true
        $this.PriorityList.Height = 5  # Show 3 items + border
        $this.PriorityList.SetItems(@("Low", "Medium", "High"))
        $this.PriorityList.SelectedIndex = 1  # Default to Medium
        $this.AddContentControl($this.PriorityList, 3)
        
        # Setup action handlers
        $this.SetupActions()
    }
    
    [void] OnActivated() {
        # Call base class first
        ([BaseDialog]$this).OnActivated()
        
        # Explicitly focus the title textbox (first field)
        $focusManager = $this.ServiceContainer.GetService('FocusManager')
        if ($focusManager -and $this.TitleBox) {
            $focusManager.SetFocus($this.TitleBox)
        }
    }
    
    [void] SetupActions() {
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
                    Title = $dialog.TitleField.Value.Trim()
                    Description = $dialog.DescriptionField.Value.Trim()
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
    
}
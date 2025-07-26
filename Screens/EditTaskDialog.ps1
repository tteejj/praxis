# EditTaskDialog.ps1 - Dialog for editing existing tasks

class EditTaskDialog : BaseDialog {
    [Task]$Task
    [MinimalTextBox]$TitleBox
    [MinimalTextBox]$DescriptionBox
    [MinimalListBox]$StatusList
    [MinimalListBox]$PriorityList
    [MinimalTextBox]$ProgressBox
    [scriptblock]$OnSave = {}
    [scriptblock]$OnCancel = {}
    
    EditTaskDialog([Task]$task) : base("Edit Task") {
        $this.Task = $task
        $this.PrimaryButtonText = "Save"
        $this.SecondaryButtonText = "Cancel"
        $this.DialogWidth = 60
        $this.DialogHeight = 20
    }
    
    [void] InitializeContent() {
        # Create title textbox
        $this.TitleBox = [MinimalTextBox]::new()
        $this.TitleBox.Text = $this.Task.Title
        $this.TitleBox.Placeholder = "Enter task title..."
        $this.TitleBox.ShowBorder = $true
        $this.TitleBox.BorderType = [BorderType]::Rounded
        $this.AddContentControl($this.TitleBox, 1)
        
        # Create description textbox
        $this.DescriptionBox = [MinimalTextBox]::new()
        $this.DescriptionBox.Text = $this.Task.Description
        $this.DescriptionBox.Placeholder = "Enter description (optional)..."
        $this.DescriptionBox.ShowBorder = $true
        $this.DescriptionBox.BorderType = [BorderType]::Rounded
        $this.AddContentControl($this.DescriptionBox, 2)
        
        # Create status list
        $this.StatusList = [MinimalListBox]::new()
        $this.StatusList.Title = "Status"
        $this.StatusList.ShowBorder = $true
        $this.StatusList.BorderType = [BorderType]::Rounded
        $this.StatusList.SetItems(@(
            @{Name="Pending"; Value=[TaskStatus]::Pending},
            @{Name="In Progress"; Value=[TaskStatus]::InProgress},
            @{Name="Completed"; Value=[TaskStatus]::Completed},
            @{Name="Cancelled"; Value=[TaskStatus]::Cancelled}
        ))
        $this.StatusList.ItemRenderer = { param($item) $item.Name }
        # Select current status
        for ($i = 0; $i -lt $this.StatusList.Items.Count; $i++) {
            if ($this.StatusList.Items[$i].Value -eq $this.Task.Status) {
                $this.StatusList.SelectIndex($i)
                break
            }
        }
        $this.AddContentControl($this.StatusList, 3)
        
        # Create priority list
        $this.PriorityList = [MinimalListBox]::new()
        $this.PriorityList.Title = "Priority"
        $this.PriorityList.ShowBorder = $true
        $this.PriorityList.BorderType = [BorderType]::Rounded
        $this.PriorityList.SetItems(@(
            @{Name="Low"; Value=[TaskPriority]::Low},
            @{Name="Medium"; Value=[TaskPriority]::Medium},
            @{Name="High"; Value=[TaskPriority]::High}
        ))
        $this.PriorityList.ItemRenderer = { param($item) $item.Name }
        # Select current priority
        for ($i = 0; $i -lt $this.PriorityList.Items.Count; $i++) {
            if ($this.PriorityList.Items[$i].Value -eq $this.Task.Priority) {
                $this.PriorityList.SelectIndex($i)
                break
            }
        }
        $this.AddContentControl($this.PriorityList, 4)
        
        # Create progress textbox
        $this.ProgressBox = [MinimalTextBox]::new()
        $this.ProgressBox.Text = $this.Task.Progress.ToString()
        $this.ProgressBox.Placeholder = "0-100"
        $this.ProgressBox.ShowBorder = $true
        $this.ProgressBox.BorderType = [BorderType]::Rounded
        $this.AddContentControl($this.ProgressBox, 5)
        
        # Set up primary action (Save)
        $dialog = $this
        $this.OnPrimary = {
            if ($dialog.TitleBox.Text.Trim()) {
                $selectedStatus = $dialog.StatusList.GetSelectedItem()
                $selectedPriority = $dialog.PriorityList.GetSelectedItem()
                $progress = 0
                if ([int]::TryParse($dialog.ProgressBox.Text, [ref]$progress)) {
                    $progress = [Math]::Max(0, [Math]::Min(100, $progress))
                }
                
                if ($dialog.OnSave) {
                    & $dialog.OnSave @{
                        Title = $dialog.TitleBox.Text
                        Description = $dialog.DescriptionBox.Text
                        Status = if ($selectedStatus) { $selectedStatus.Value } else { $dialog.Task.Status }
                        Priority = if ($selectedPriority) { $selectedPriority.Value } else { $dialog.Task.Priority }
                        Progress = $progress
                    }
                }
            }
        }.GetNewClosure()
        
        # Set up secondary action (Cancel)
        $this.OnSecondary = {
            if ($dialog.OnCancel) {
                & $dialog.OnCancel
            }
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Custom positioning for task dialog
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        $currentY = $dialogY + 2
        
        # Title
        $this.TitleBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 3)
        $currentY += 3
        
        # Description
        $this.DescriptionBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 3)
        $currentY += 3
        
        # Status and Priority side by side
        $halfWidth = [int](($controlWidth - 2) / 2)
        $this.StatusList.SetBounds($dialogX + $this.DialogPadding, $currentY, $halfWidth, 5)
        $this.PriorityList.SetBounds($dialogX + $this.DialogPadding + $halfWidth + 2, $currentY, $halfWidth, 5)
        $currentY += 6
        
        # Progress
        $this.ProgressBox.SetBounds($dialogX + $this.DialogPadding, $currentY, 20, 3)
    }
}
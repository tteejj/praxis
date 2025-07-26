# EditProjectDialog.ps1 - Dialog for editing existing projects

class EditProjectDialog : BaseDialog {
    [Project]$Project
    [TextBox]$NameBox
    [TextBox]$NicknameBox
    [TextBox]$ID1Box
    [TextBox]$ID2Box
    [TextBox]$NoteBox
    [TextBox]$CAAPathBox
    [TextBox]$RequestPathBox
    [TextBox]$T2020PathBox
    [TextBox]$DueDateBox
    
    EditProjectDialog([Project]$project) : base("Edit Project") {
        $this.Project = $project
        $this.PrimaryButtonText = "Save"
        $this.SecondaryButtonText = "Cancel"
        $this.DialogWidth = 70
        $this.DialogHeight = 22
    }
    
    [void] InitializeContent() {
        # Create all project input fields with current values
        $this.NameBox = [TextBox]::new()
        $this.NameBox.Text = $this.Project.FullProjectName
        $this.NameBox.Placeholder = "Enter full project name..."
        $this.AddContentControl($this.NameBox, 1)
        
        $this.NicknameBox = [TextBox]::new()
        $this.NicknameBox.Text = $this.Project.Nickname
        $this.NicknameBox.Placeholder = "Enter project nickname..."
        $this.AddContentControl($this.NicknameBox, 2)
        
        $this.ID1Box = [TextBox]::new()
        $this.ID1Box.Text = $this.Project.ID1
        $this.ID1Box.Placeholder = "Enter ID1..."
        $this.AddContentControl($this.ID1Box, 3)
        
        $this.ID2Box = [TextBox]::new()
        $this.ID2Box.Text = $this.Project.ID2
        $this.ID2Box.Placeholder = "Enter ID2..."
        $this.AddContentControl($this.ID2Box, 4)
        
        $this.NoteBox = [TextBox]::new()
        $this.NoteBox.Text = $this.Project.Note
        $this.NoteBox.Placeholder = "Enter notes..."
        $this.AddContentControl($this.NoteBox, 5)
        
        $this.CAAPathBox = [TextBox]::new()
        $this.CAAPathBox.Text = $this.Project.CAAPath
        $this.CAAPathBox.Placeholder = "Enter CAA path..."
        $this.AddContentControl($this.CAAPathBox, 6)
        
        $this.RequestPathBox = [TextBox]::new()
        $this.RequestPathBox.Text = $this.Project.RequestPath
        $this.RequestPathBox.Placeholder = "Enter request path..."
        $this.AddContentControl($this.RequestPathBox, 7)
        
        $this.T2020PathBox = [TextBox]::new()
        $this.T2020PathBox.Text = $this.Project.T2020Path
        $this.T2020PathBox.Placeholder = "Enter T2020 path..."
        $this.AddContentControl($this.T2020PathBox, 8)
        
        $this.DueDateBox = [TextBox]::new()
        $this.DueDateBox.Text = $this.Project.DateDue.ToString("MM/dd/yyyy")
        $this.DueDateBox.Placeholder = "Enter due date (MM/DD/YYYY)..."
        $this.AddContentControl($this.DueDateBox, 9)
        
        # Set up primary action (Save)
        $dialog = $this
        $this.OnPrimary = {
            if ($dialog.NameBox.Text.Trim()) {
                # Parse due date
                $dueDate = $dialog.Project.DateDue
                if ($dialog.DueDateBox.Text.Trim()) {
                    try {
                        $dueDate = [DateTime]::Parse($dialog.DueDateBox.Text)
                    } catch {
                        # Keep original date if parsing fails
                    }
                }
                
                # Update project properties
                $dialog.Project.FullProjectName = $dialog.NameBox.Text
                $dialog.Project.Nickname = $dialog.NicknameBox.Text
                $dialog.Project.ID1 = $dialog.ID1Box.Text
                $dialog.Project.ID2 = $dialog.ID2Box.Text
                $dialog.Project.Note = $dialog.NoteBox.Text
                $dialog.Project.CAAPath = $dialog.CAAPathBox.Text
                $dialog.Project.RequestPath = $dialog.RequestPathBox.Text
                $dialog.Project.T2020Path = $dialog.T2020PathBox.Text
                $dialog.Project.DateDue = $dueDate
                $dialog.Project.UpdatedAt = [DateTime]::Now
                
                # Save via service
                $projectService = $global:ServiceContainer.GetService("ProjectService")
                if ($projectService) {
                    $projectService.SaveProject($dialog.Project)
                }
                
                # Publish event if EventBus available
                if ($dialog.EventBus) {
                    $dialog.EventBus.Publish([EventNames]::ProjectUpdated, @{ 
                        Project = $dialog.Project 
                    })
                    
                    $dialog.EventBus.Publish([EventNames]::DialogClosed, @{ 
                        Dialog = 'EditProjectDialog'
                        Action = 'Save'
                        Data = $dialog.Project
                    })
                }
            }
        }.GetNewClosure()
        
        # Set up secondary action (Cancel)
        $this.OnSecondary = {
            if ($dialog.EventBus) {
                $dialog.EventBus.Publish([EventNames]::DialogClosed, @{ 
                    Dialog = 'EditProjectDialog'
                    Action = 'Cancel'
                })
            }
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Custom positioning for all project fields (same as NewProjectDialog)
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        $currentY = $dialogY + 2
        
        $this.NameBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 2)
        $currentY += 2
        
        $this.NicknameBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 2)
        $currentY += 2
        
        # Split ID fields horizontally
        $halfWidth = [int](($controlWidth - 2) / 2)
        $this.ID1Box.SetBounds($dialogX + $this.DialogPadding, $currentY, $halfWidth, 2)
        $this.ID2Box.SetBounds($dialogX + $this.DialogPadding + $halfWidth + 2, $currentY, $halfWidth, 2)
        $currentY += 2
        
        $this.NoteBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 2)
        $currentY += 2
        
        $this.CAAPathBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 2)
        $currentY += 2
        
        $this.RequestPathBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 2)
        $currentY += 2
        
        $this.T2020PathBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 2)
        $currentY += 2
        
        $this.DueDateBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 2)
    }
}
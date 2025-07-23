# NewProjectDialog.ps1 - Dialog for creating new projects (refactored to use BaseDialog)

class NewProjectDialog : BaseDialog {
    [TextBox]$NameBox
    [TextBox]$NicknameBox
    [TextBox]$ID1Box
    [TextBox]$ID2Box
    [TextBox]$NotesBox
    [TextBox]$CAAPathBox
    [TextBox]$RequestPathBox
    [TextBox]$T2020PathBox
    [TextBox]$DueDateBox
    
    NewProjectDialog() : base("New Project") {
        $this.PrimaryButtonText = "Create"
        $this.SecondaryButtonText = "Cancel"
        $this.DialogWidth = 70
        $this.DialogHeight = 22
    }
    
    [void] InitializeContent() {
        # Create all project input fields
        $this.NameBox = [TextBox]::new()
        $this.NameBox.Placeholder = "Enter full project name..."
        $this.AddContentControl($this.NameBox, 1)
        
        $this.NicknameBox = [TextBox]::new()
        $this.NicknameBox.Placeholder = "Enter project nickname..."
        $this.AddContentControl($this.NicknameBox, 2)
        
        $this.ID1Box = [TextBox]::new()
        $this.ID1Box.Placeholder = "Enter ID1..."
        $this.AddContentControl($this.ID1Box, 3)
        
        $this.ID2Box = [TextBox]::new()
        $this.ID2Box.Placeholder = "Enter ID2..."
        $this.AddContentControl($this.ID2Box, 4)
        
        $this.NotesBox = [TextBox]::new()
        $this.NotesBox.Placeholder = "Enter notes..."
        $this.AddContentControl($this.NotesBox, 5)
        
        $this.CAAPathBox = [TextBox]::new()
        $this.CAAPathBox.Placeholder = "Enter CAA path..."
        $this.AddContentControl($this.CAAPathBox, 6)
        
        $this.RequestPathBox = [TextBox]::new()
        $this.RequestPathBox.Placeholder = "Enter request path..."
        $this.AddContentControl($this.RequestPathBox, 7)
        
        $this.T2020PathBox = [TextBox]::new()
        $this.T2020PathBox.Placeholder = "Enter T2020 path..."
        $this.AddContentControl($this.T2020PathBox, 8)
        
        $this.DueDateBox = [TextBox]::new()
        $this.DueDateBox.Placeholder = "Enter due date (MM/DD/YYYY)..."
        $this.DueDateBox.Text = ([DateTime]::Now.AddDays(42)).ToString("MM/dd/yyyy")
        $this.AddContentControl($this.DueDateBox, 9)
        
        # Set up primary action
        $dialog = $this
        $this.OnPrimary = {
            if ($dialog.NameBox.Text.Trim()) {
                # Parse due date
                $dueDate = [DateTime]::Now.AddDays(42)
                if ($dialog.DueDateBox.Text.Trim()) {
                    try {
                        $dueDate = [DateTime]::Parse($dialog.DueDateBox.Text)
                    } catch {
                        # Use default if parsing fails
                        $dueDate = [DateTime]::Now.AddDays(42)
                    }
                }
                
                $projectData = @{
                    FullProjectName = $dialog.NameBox.Text
                    Nickname = if ($dialog.NicknameBox.Text.Trim()) { $dialog.NicknameBox.Text } else { $dialog.NameBox.Text }
                    ID1 = $dialog.ID1Box.Text
                    ID2 = $dialog.ID2Box.Text
                    Note = $dialog.NotesBox.Text
                    CAAPath = $dialog.CAAPathBox.Text
                    RequestPath = $dialog.RequestPathBox.Text
                    T2020Path = $dialog.T2020PathBox.Text
                    DateDue = $dueDate
                }
                
                # Use EventBus if available
                if ($dialog.EventBus) {
                    # Create project via service
                    $projectService = $global:ServiceContainer.GetService("ProjectService")
                    if ($projectService) {
                        # Create project with full data
                        $newProject = $projectService.AddProject($projectData.FullProjectName, $projectData.Nickname)
                        
                        # Update additional properties
                        $newProject.ID1 = $projectData.ID1
                        $newProject.ID2 = $projectData.ID2
                        $newProject.Note = $projectData.Note
                        $newProject.CAAPath = $projectData.CAAPath
                        $newProject.RequestPath = $projectData.RequestPath
                        $newProject.T2020Path = $projectData.T2020Path
                        $newProject.DateDue = $projectData.DateDue
                        
                        # Save the updated project
                        $projectService.SaveProject($newProject)
                        
                        # Publish event
                        $dialog.EventBus.Publish([EventNames]::ProjectCreated, @{ 
                            Project = $newProject 
                        })
                    }
                    
                    # Publish dialog closed event
                    $dialog.EventBus.Publish([EventNames]::DialogClosed, @{ 
                        Dialog = 'NewProjectDialog'
                        Action = 'Create'
                        Data = $projectData
                    })
                } else {
                    # Legacy callback support
                    if ($dialog.OnCreate -and $dialog.OnCreate.GetType().Name -eq 'ScriptBlock') {
                        & $dialog.OnCreate $projectData
                    }
                }
            }
        }.GetNewClosure()
        
        # Set up secondary action
        $this.OnSecondary = {
            # Publish dialog closed event
            if ($dialog.EventBus) {
                $dialog.EventBus.Publish([EventNames]::DialogClosed, @{ 
                    Dialog = 'NewProjectDialog'
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
        # Custom positioning for all project fields
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
        
        $this.NotesBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 2)
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
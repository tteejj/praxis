# NewProjectDialog.ps1 - Dialog for creating new projects (refactored to use BaseDialog)

class NewProjectDialog : BaseDialog {
    [MinimalTextBox]$NameBox
    [MinimalTextBox]$ID1Box
    [MinimalTextBox]$ID2Box
    [MinimalTextBox]$NotesBox
    [MinimalTextBox]$CAAPathBox
    [MinimalTextBox]$RequestPathBox
    [MinimalTextBox]$T2020PathBox
    [MinimalTextBox]$DueDateBox
    
    NewProjectDialog() : base("New Project") {
        $this.PrimaryButtonText = "Create"
        $this.SecondaryButtonText = "Cancel"
        $this.DialogWidth = 70
        $this.DialogHeight = 24  # 8 fields * 2 + 2 padding + 4 for buttons + 2 for title
    }
    
    [void] InitializeContent() {
        # Create all project input fields
        $this.NameBox = [MinimalTextBox]::new()
        $this.NameBox.Placeholder = "Enter full project name..."
        $this.NameBox.ShowBorder = $false  # Dialog provides the border
        $this.NameBox.Height = 1  # Just the text line
        $this.AddContentControl($this.NameBox, 1)
        
        $this.ID1Box = [MinimalTextBox]::new()
        $this.ID1Box.Placeholder = "Enter ID1..."
        $this.ID1Box.ShowBorder = $false
        $this.ID1Box.Height = 1
        $this.AddContentControl($this.ID1Box, 2)
        
        $this.ID2Box = [MinimalTextBox]::new()
        $this.ID2Box.Placeholder = "Enter ID2..."
        $this.ID2Box.ShowBorder = $false
        $this.ID2Box.Height = 1
        $this.AddContentControl($this.ID2Box, 3)
        
        $this.NotesBox = [MinimalTextBox]::new()
        $this.NotesBox.Placeholder = "Enter notes..."
        $this.NotesBox.ShowBorder = $false
        $this.NotesBox.Height = 1
        $this.AddContentControl($this.NotesBox, 4)
        
        $this.CAAPathBox = [MinimalTextBox]::new()
        $this.CAAPathBox.Placeholder = "Enter CAA path..."
        $this.CAAPathBox.ShowBorder = $false
        $this.CAAPathBox.Height = 1
        $this.AddContentControl($this.CAAPathBox, 5)
        
        $this.RequestPathBox = [MinimalTextBox]::new()
        $this.RequestPathBox.Placeholder = "Enter request path..."
        $this.RequestPathBox.ShowBorder = $false
        $this.RequestPathBox.Height = 1
        $this.AddContentControl($this.RequestPathBox, 6)
        
        $this.T2020PathBox = [MinimalTextBox]::new()
        $this.T2020PathBox.Placeholder = "Enter T2020 path..."
        $this.T2020PathBox.ShowBorder = $false
        $this.T2020PathBox.Height = 1
        $this.AddContentControl($this.T2020PathBox, 7)
        
        $this.DueDateBox = [MinimalTextBox]::new()
        $this.DueDateBox.Placeholder = "Enter due date (MM/DD/YYYY)..."
        $this.DueDateBox.Text = ([DateTime]::Now.AddDays(42)).ToString("MM/dd/yyyy")
        $this.DueDateBox.ShowBorder = $false
        $this.DueDateBox.Height = 1
        $this.AddContentControl($this.DueDateBox, 8)
        
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
                        $newProject = $projectService.AddProject($projectData.FullProjectName)
                        
                        # Update additional properties
                        $newProject.ID1 = $projectData.ID1
                        $newProject.ID2 = $projectData.ID2
                        $newProject.Note = $projectData.Note
                        $newProject.CAAPath = $projectData.CAAPath
                        $newProject.RequestPath = $projectData.RequestPath
                        $newProject.T2020Path = $projectData.T2020Path
                        $newProject.DateDue = $projectData.DateDue
                        
                        # Save the updated project
                        $projectService.UpdateProject($newProject)
                        
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
        
        $this.NameBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2  # 1 for field + 1 for spacing
        
        # Split ID fields horizontally
        $halfWidth = [int](($controlWidth - 2) / 2)
        $this.ID1Box.SetBounds($dialogX + $this.DialogPadding, $currentY, $halfWidth, 1)
        $this.ID2Box.SetBounds($dialogX + $this.DialogPadding + $halfWidth + 2, $currentY, $halfWidth, 1)
        $currentY += 2
        
        $this.NotesBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2
        
        $this.CAAPathBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2
        
        $this.RequestPathBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2
        
        $this.T2020PathBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
        $currentY += 2
        
        $this.DueDateBox.SetBounds($dialogX + $this.DialogPadding, $currentY, $controlWidth, 1)
    }
}
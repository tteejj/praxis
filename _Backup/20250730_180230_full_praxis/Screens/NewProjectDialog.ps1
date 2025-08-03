# NewProjectDialog.ps1 - Dialog for creating new projects (refactored to use BaseDialog)

class NewProjectDialog : BaseDialog {
    [DialogField]$NameField
    [DialogField]$ID1Field
    [DialogField]$ID2Field
    [DialogField]$NotesField
    [DialogField]$CAAPathField
    [DialogField]$RequestPathField
    [DialogField]$T2020PathField
    [DialogField]$DueDateField
    
    NewProjectDialog() : base("New Project") {
        $this.PrimaryButtonText = "Create"
        $this.SecondaryButtonText = "Cancel"
        $this.DialogWidth = 70
        $this.DialogHeight = 22  # Adjusted for proper spacing
    }
    
    [void] InitializeContent() {
        # Create all project input fields using DialogField
        $this.NameField = [DialogField]::new("Project Name", "Enter full project name...")
        $this.NameField.KeyWidth = 14
        $this.AddContentControl($this.NameField, 1)
        
        $this.ID1Field = [DialogField]::new("ID1", "Enter ID1...")
        $this.ID1Field.KeyWidth = 14
        $this.AddContentControl($this.ID1Field, 2)
        
        $this.ID2Field = [DialogField]::new("ID2", "Enter ID2...")
        $this.ID2Field.KeyWidth = 14
        $this.AddContentControl($this.ID2Field, 3)
        
        $this.NotesField = [DialogField]::new("Notes", "Enter notes...")
        $this.NotesField.KeyWidth = 14
        $this.AddContentControl($this.NotesField, 4)
        
        $this.CAAPathField = [DialogField]::new("CAA Path", "Enter CAA path...")
        $this.CAAPathField.KeyWidth = 14
        $this.AddContentControl($this.CAAPathField, 5)
        
        $this.RequestPathField = [DialogField]::new("Request Path", "Enter request path...")
        $this.RequestPathField.KeyWidth = 14
        $this.AddContentControl($this.RequestPathField, 6)
        
        $this.T2020PathField = [DialogField]::new("T2020 Path", "Enter T2020 path...")
        $this.T2020PathField.KeyWidth = 14
        $this.AddContentControl($this.T2020PathField, 7)
        
        $this.DueDateField = [DialogField]::new("Due Date", "Enter due date (MM/DD/YYYY)...")
        $this.DueDateField.KeyWidth = 14
        $this.DueDateField.SetValue(([DateTime]::Now.AddDays(42)).ToString("MM/dd/yyyy"))
        $this.AddContentControl($this.DueDateField, 8)
        
        # Set up primary action
        $dialog = $this
        $this.OnPrimary = {
            if ($dialog.NameField.Value.Trim()) {
                # Parse due date
                $dueDate = [DateTime]::Now.AddDays(42)
                if ($dialog.DueDateField.Value.Trim()) {
                    try {
                        $dueDate = [DateTime]::Parse($dialog.DueDateField.Value)
                    } catch {
                        # Use default if parsing fails
                        $dueDate = [DateTime]::Now.AddDays(42)
                    }
                }
                
                $projectData = @{
                    FullProjectName = $dialog.NameField.Value
                    ID1 = $dialog.ID1Field.Value
                    ID2 = $dialog.ID2Field.Value
                    Note = $dialog.NotesField.Value
                    CAAPath = $dialog.CAAPathField.Value
                    RequestPath = $dialog.RequestPathField.Value
                    T2020Path = $dialog.T2020PathField.Value
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
    
    [void] OnActivated() {
        # Call base class first
        ([BaseDialog]$this).OnActivated()
        
        # Explicitly focus the name field (first field)
        $focusManager = $this.ServiceContainer.GetService('FocusManager')
        if ($focusManager -and $this.NameField) {
            $focusManager.SetFocus($this.NameField)
        }
    }
    
}


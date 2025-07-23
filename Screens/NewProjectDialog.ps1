# NewProjectDialog.ps1 - Dialog for creating new projects (refactored to use BaseDialog)

class NewProjectDialog : BaseDialog {
    [TextBox]$NameBox
    [TextBox]$DescriptionBox
    
    NewProjectDialog() : base("New Project") {
        $this.PrimaryButtonText = "Create"
        $this.SecondaryButtonText = "Cancel"
    }
    
    [void] InitializeContent() {
        # Create name textbox
        $this.NameBox = [TextBox]::new()
        $this.NameBox.Placeholder = "Enter project name..."
        $this.AddContentControl($this.NameBox, 1)
        
        # Create description textbox
        $this.DescriptionBox = [TextBox]::new()
        $this.DescriptionBox.Placeholder = "Enter description..."
        $this.AddContentControl($this.DescriptionBox, 2)
        
        # Set up primary action
        $dialog = $this
        $this.OnPrimary = {
            if ($dialog.NameBox.Text.Trim()) {
                $projectData = @{
                    Name = $dialog.NameBox.Text
                    Description = $dialog.DescriptionBox.Text
                }
                
                # Use EventBus if available
                if ($dialog.EventBus) {
                    # Create project via service
                    $projectService = $global:ServiceContainer.GetService("ProjectService")
                    if ($projectService) {
                        # Create project using single-parameter constructor
                        $newProject = $projectService.AddProject($projectData.Name)
                        
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
        # Custom positioning for name and description
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        
        # Name box
        $this.NameBox.SetBounds(
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
    }
}
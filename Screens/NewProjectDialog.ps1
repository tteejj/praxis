# NewProjectDialog.ps1 - Dialog for creating new projects using UnifiedDialog

class NewProjectDialog : UnifiedDialog {
    NewProjectDialog() : base("New Project", 70, 18) {
        # Add project fields using simplified UnifiedDialog API
        $this.AddField("name", "Project Name", "")
        $this.AddField("id1", "ID1", "") 
        $this.AddField("id2", "ID2", "")
        $this.AddField("notes", "Notes", "")
        $this.AddField("caaPath", "CAA Path", "")
        $this.AddField("requestPath", "Request Path", "")
        $this.AddField("t2020Path", "T2020 Path", "")
        
        # Set button labels
        $this.SetButtons("Create", "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.CreateProject() }.GetNewClosure()
    }
    
    [void] CreateProject() {
        # Get field values
        $projectData = @{
            Name = $this.GetFieldValue("name")
            ID1 = $this.GetFieldValue("id1")
            ID2 = $this.GetFieldValue("id2")  
            Notes = $this.GetFieldValue("notes")
            CAAPath = $this.GetFieldValue("caaPath")
            RequestPath = $this.GetFieldValue("requestPath")
            T2020Path = $this.GetFieldValue("t2020Path")
        }
        
        # Validate required fields
        if ([string]::IsNullOrWhiteSpace($projectData.Name)) {
            # Show error - for now just return
            return
        }
        
        # Get project service and create project
        $projectService = $this.GetService("ProjectService")
        if ($projectService) {
            try {
                $project = $projectService.AddProject($projectData.Name)
                
                # Update additional fields if provided
                if ($projectData.ID1) { $project.ID1 = $projectData.ID1 }
                if ($projectData.ID2) { $project.ID2 = $projectData.ID2 }
                if ($projectData.Notes) { $project.Notes = $projectData.Notes }
                if ($projectData.CAAPath) { $project.CAAPath = $projectData.CAAPath }
                if ($projectData.RequestPath) { $project.RequestPath = $projectData.RequestPath }
                if ($projectData.T2020Path) { $project.T2020Path = $projectData.T2020Path }
                
                # Manually refresh the projects screen instead of using events
                # Find the ProjectsScreen by type name to avoid loading order issues
                if ($global:ScreenManager -and $global:ScreenManager.Screens.Count -gt 0) {
                    foreach ($screen in $global:ScreenManager.Screens) {
                        if ($screen.GetType().Name -eq "ProjectsScreen") {
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
                    $global:Logger.Error("Failed to create project: $_")
                }
            }
        }
    }
}
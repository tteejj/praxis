# EditProjectDialog.ps1 - Dialog for editing existing projects using UnifiedDialog

class EditProjectDialog : UnifiedDialog {
    [Project]$Project
    
    EditProjectDialog([Project]$project) : base("Edit Project", 70, 20) {
        $this.Project = $project
        
        # Add project fields using simplified UnifiedDialog API with current values
        $this.AddField("name", "Project Name", $project.FullProjectName)
        $this.AddField("id1", "ID1", $project.ID1) 
        $this.AddField("id2", "ID2", $project.ID2)
        $this.AddField("notes", "Notes", $project.Note)
        $this.AddField("caaPath", "CAA Path", $project.CAAPath)
        $this.AddField("requestPath", "Request Path", $project.RequestPath)
        $this.AddField("t2020Path", "T2020 Path", $project.T2020Path)
        $this.AddField("dueDate", "Due Date (MM/DD/YYYY)", $project.DateDue.ToString("MM/dd/yyyy"))
        
        # Set button labels
        $this.SetButtons("Save", "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.SaveProject() }.GetNewClosure()
    }
    
    [void] SaveProject() {
        # Get field values
        $name = $this.GetFieldValue("name")
        
        # Validate required fields
        if ([string]::IsNullOrWhiteSpace($name)) {
            # Show error - for now just return
            return
        }
        
        # Parse due date
        $dueDate = $this.Project.DateDue
        $dueDateText = $this.GetFieldValue("dueDate")
        if (-not [string]::IsNullOrWhiteSpace($dueDateText)) {
            try {
                $dueDate = [DateTime]::Parse($dueDateText)
            } catch {
                # Keep original date if parsing fails
            }
        }
        
        # Update project properties
        $this.Project.FullProjectName = $name
        $this.Project.ID1 = $this.GetFieldValue("id1")
        $this.Project.ID2 = $this.GetFieldValue("id2")
        $this.Project.Note = $this.GetFieldValue("notes")
        $this.Project.CAAPath = $this.GetFieldValue("caaPath")
        $this.Project.RequestPath = $this.GetFieldValue("requestPath")
        $this.Project.T2020Path = $this.GetFieldValue("t2020Path")
        $this.Project.DateDue = $dueDate
        $this.Project.UpdatedAt = [DateTime]::Now
        
        # Save via service
        $projectService = $this.GetService("ProjectService")
        if ($projectService) {
            try {
                $projectService.UpdateProject($this.Project)
                
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
                    $global:Logger.Error("Failed to update project: $_")
                }
            }
        }
    }
}
# CleanNewProjectDialog.ps1 - CLEAN new project dialog using UnifiedDialog

class CleanNewProjectDialog : UnifiedDialog {
    
    CleanNewProjectDialog() : base("New Project", 70, 20) {
        # Add project fields using simplified UnifiedDialog API
        $this.AddField("name", "Project Name", "")
        $this.AddField("id1", "ID1", "") 
        $this.AddField("id2", "ID2", "")
        $this.AddField("notes", "Notes", "")
        $this.AddField("caaPath", "CAA Path", "")
        $this.AddField("requestPath", "Request Path", "")
        $this.AddField("t2020Path", "T2020 Path", "")
        $this.AddField("dueDate", "Due Date", [DateTime]::Now.AddDays(42).ToString("MM/dd/yyyy"))
        
        # Set button labels
        $this.SetButtons("Create", "Cancel")
        
        # Set up submit handler with proper closure
        $dialog = $this
        $this.OnSubmit = { $dialog.CreateProject() }.GetNewClosure()
    }
    
    [void] CreateProject() {
        # Get field values
        $projectName = $this.GetFieldValue("name")
        
        # Validate required fields
        if ([string]::IsNullOrWhiteSpace($projectName)) {
            # Show error - for now just return
            return
        }
        
        # Get project service and create project
        $projectService = $this.GetService("ProjectService")
        if ($projectService) {
            try {
                $project = $projectService.AddProject($projectName)
                
                # Update additional fields if provided
                if ($this.GetFieldValue("id1")) { $project.ID1 = $this.GetFieldValue("id1") }
                if ($this.GetFieldValue("id2")) { $project.ID2 = $this.GetFieldValue("id2") }
                if ($this.GetFieldValue("notes")) { $project.Note = $this.GetFieldValue("notes") }
                if ($this.GetFieldValue("caaPath")) { $project.CAAPath = $this.GetFieldValue("caaPath") }
                if ($this.GetFieldValue("requestPath")) { $project.RequestPath = $this.GetFieldValue("requestPath") }
                if ($this.GetFieldValue("t2020Path")) { $project.T2020Path = $this.GetFieldValue("t2020Path") }
                
                # Parse due date
                try {
                    $project.DateDue = [DateTime]::Parse($this.GetFieldValue("dueDate"))
                } catch {
                    $project.DateDue = [DateTime]::Now.AddDays(42)
                }
                
                # Save the updated project
                $projectService.UpdateProject($project)
                
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
                
                # Show success toast if available
                $toastService = $this.GetService("ToastService")
                if ($toastService) {
                    $toastService.ShowSuccess("Project created: $projectName")
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
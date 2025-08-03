# SimpleNewProjectDialog.ps1 - New Project Dialog that WORKS

class SimpleNewProjectDialog : SimpleDialog {
    
    SimpleNewProjectDialog() : base("New Project") {
        $this.DialogWidth = 70
        $this.DialogHeight = 22
        
        # Add all fields
        $this.AddField("Name", "Project Name", "")
        $this.AddField("ID1", "ID1", "")
        $this.AddField("ID2", "ID2", "")
        $this.AddField("Notes", "Notes", "")
        $this.AddField("CAAPath", "CAA Path", "")
        $this.AddField("RequestPath", "Request Path", "")
        $this.AddField("T2020Path", "T2020 Path", "")
        $this.AddField("DueDate", "Due Date", [DateTime]::Now.AddDays(42).ToString("MM/dd/yyyy"))
        
        # Set up OK handler
        $dialog = $this
        $this.OnOK = {
            if ($dialog.Values["Name"].Trim()) {
                # Get project service and create project
                $projectService = $global:ServiceContainer.GetService("ProjectService")
                if ($projectService) {
                    # Create project
                    $project = $projectService.AddProject($dialog.Values["Name"])
                    
                    # Set all fields
                    $project.ID1 = $dialog.Values["ID1"]
                    $project.ID2 = $dialog.Values["ID2"]
                    $project.Note = $dialog.Values["Notes"]
                    $project.CAAPath = $dialog.Values["CAAPath"]
                    $project.RequestPath = $dialog.Values["RequestPath"]
                    $project.T2020Path = $dialog.Values["T2020Path"]
                    
                    # Parse date
                    try {
                        $project.DateDue = [DateTime]::Parse($dialog.Values["DueDate"])
                    } catch {
                        $project.DateDue = [DateTime]::Now.AddDays(42)
                    }
                    
                    # Save
                    $projectService.UpdateProject($project)
                    
                    # Notify via EventBus
                    $eventBus = $global:ServiceContainer.GetService("EventBus")
                    if ($eventBus) {
                        $eventBus.Publish([EventNames]::ProjectCreated, @{
                            Project = $project
                            Source = "SimpleNewProjectDialog"
                        })
                    }
                    
                    # Show toast
                    $toastService = $global:ServiceContainer.GetService("ToastService")
                    if ($toastService) {
                        $toastService.ShowSuccess("Project '$($project.FullProjectName)' created!")
                    }
                }
            }
        }.GetNewClosure()
    }
}
# ProjectCommandHandler.ps1 - Handles project-specific commands

class ProjectCommandHandler {
    [ProjectService]$ProjectService
    [EventBus]$EventBus
    [Logger]$Logger
    [ToastService]$ToastService
    
    ProjectCommandHandler([ServiceContainer]$container) {
        $this.ProjectService = $container.GetService('ProjectService')
        $this.EventBus = $container.GetService('EventBus')
        $this.Logger = $container.GetService('Logger')
        $this.ToastService = $container.GetService('ToastService')
    }
    
    [bool] ExecuteCommand([ParsedCommand]$command) {
        if ($this.Logger) {
            $this.Logger.Debug("ProjectCommandHandler: Executing command - $($command.OriginalCommand)")
        }
        
        try {
            switch ($command.Verb) {
                'add' { return $this.HandleAdd($command) }
                'new' { return $this.HandleAdd($command) }
                'create' { return $this.HandleAdd($command) }
                'edit' { return $this.HandleEdit($command) }
                'update' { return $this.HandleEdit($command) }
                'delete' { return $this.HandleDelete($command) }
                'remove' { return $this.HandleDelete($command) }
                'close' { return $this.HandleClose($command) }
                'open' { return $this.HandleOpen($command) }
                'filter' { return $this.HandleFilter($command) }
                'sort' { return $this.HandleSort($command) }
                'export' { return $this.HandleExport($command) }
                'list' { return $this.HandleList($command) }
                'find' { return $this.HandleFind($command) }
                default {
                    $this.ShowError("Unknown command: $($command.Verb)")
                    return $false
                }
            }
        }
        catch {
            $this.ShowError("Error executing command: $_")
            if ($this.Logger) {
                $this.Logger.Error("ProjectCommandHandler error: $_")
            }
            return $false
        }
        
        # This should never be reached due to switch statement, but PowerShell requires it
        return $false
    }
    
    [bool] HandleAdd([ParsedCommand]$command) {
        $name = [CommandParser]::GetParameterValue($command, 'name')
        if ([string]::IsNullOrEmpty($name)) {
            $this.ShowError("Project name is required. Usage: :add project <name> [due: <date>] [id1: <id>]")
            return $false
        }
        
        # Create project
        $project = $this.ProjectService.AddProject($name)
        
        # Set optional parameters
        $dueDate = [CommandParser]::GetParameterValue($command, 'due')
        if (-not [string]::IsNullOrEmpty($dueDate)) {
            try {
                $project.DateDue = [DateTime]::Parse($dueDate)
            }
            catch {
                $this.ShowWarning("Invalid due date format: $dueDate")
            }
        }
        
        $id1 = [CommandParser]::GetParameterValue($command, 'id1')
        if (-not [string]::IsNullOrEmpty($id1)) {
            $project.ID1 = $id1
        }
        
        $id2 = [CommandParser]::GetParameterValue($command, 'id2')
        if (-not [string]::IsNullOrEmpty($id2)) {
            $project.ID2 = $id2
        }
        
        $note = [CommandParser]::GetParameterValue($command, 'note')
        if (-not [string]::IsNullOrEmpty($note)) {
            $project.Note = $note
        }
        
        # Save changes
        $this.ProjectService.UpdateProject($project)
        
        # Publish event
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::ProjectCreated, @{ Project = $project })
        }
        
        $this.ShowSuccess("Created project: $name")
        return $true
    }
    
    [bool] HandleEdit([ParsedCommand]$command) {
        $project = $this.FindProject($command)
        if (-not $project) {
            return $false
        }
        
        $changes = @()
        
        # Update name if provided
        $name = [CommandParser]::GetParameterValue($command, 'name')
        if (-not [string]::IsNullOrEmpty($name)) {
            $project.FullProjectName = $name
            $changes += "name"
        }
        
        # Update due date
        $dueDate = [CommandParser]::GetParameterValue($command, 'due')
        if (-not [string]::IsNullOrEmpty($dueDate)) {
            try {
                if ($dueDate.ToLower() -eq 'none' -or $dueDate.ToLower() -eq 'clear') {
                    $project.DateDue = [DateTime]::MinValue
                } else {
                    $project.DateDue = [DateTime]::Parse($dueDate)
                }
                $changes += "due date"
            }
            catch {
                $this.ShowWarning("Invalid due date format: $dueDate")
            }
        }
        
        # Update IDs
        $id1 = [CommandParser]::GetParameterValue($command, 'id1')
        if (-not [string]::IsNullOrEmpty($id1)) {
            $project.ID1 = $id1
            $changes += "ID1"
        }
        
        $id2 = [CommandParser]::GetParameterValue($command, 'id2')
        if (-not [string]::IsNullOrEmpty($id2)) {
            $project.ID2 = $id2
            $changes += "ID2"
        }
        
        # Update note
        $note = [CommandParser]::GetParameterValue($command, 'note')
        if (-not [string]::IsNullOrEmpty($note)) {
            $project.Note = $note
            $changes += "note"
        }
        
        if ($changes.Count -eq 0) {
            $this.ShowError("No changes specified. Specify parameters to update (name:, due:, id1:, id2:, note:)")
            return $false
        }
        
        # Save changes
        $this.ProjectService.UpdateProject($project)
        
        # Publish event
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::ProjectUpdated, @{ Project = $project })
        }
        
        $this.ShowSuccess("Updated project: $($project.FullProjectName) ($($changes -join ', '))")
        return $true
    }
    
    [bool] HandleDelete([ParsedCommand]$command) {
        $project = $this.FindProject($command)
        if (-not $project) {
            return $false
        }
        
        # Confirm deletion
        $confirmParam = [CommandParser]::GetParameterValue($command, 'confirm')
        if ($confirmParam.ToLower() -ne 'yes') {
            $this.ShowWarning("Add 'confirm: yes' to delete project: $($project.FullProjectName)")
            return $false
        }
        
        $projectName = $project.FullProjectName
        $this.ProjectService.DeleteProject($project.Id)
        
        # Publish event
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::ProjectDeleted, @{ ProjectId = $project.Id })
        }
        
        $this.ShowSuccess("Deleted project: $projectName")
        return $true
    }
    
    [bool] HandleClose([ParsedCommand]$command) {
        $project = $this.FindProject($command)
        if (-not $project) {
            return $false
        }
        
        $project.ClosedDate = [DateTime]::Now
        $this.ProjectService.UpdateProject($project)
        
        # Publish event
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::ProjectUpdated, @{ Project = $project })
        }
        
        $this.ShowSuccess("Closed project: $($project.FullProjectName)")
        return $true
    }
    
    [bool] HandleOpen([ParsedCommand]$command) {
        $project = $this.FindProject($command)
        if (-not $project) {
            return $false
        }
        
        $project.ClosedDate = [DateTime]::MinValue
        $this.ProjectService.UpdateProject($project)
        
        # Publish event
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::ProjectUpdated, @{ Project = $project })
        }
        
        $this.ShowSuccess("Reopened project: $($project.FullProjectName)")
        return $true
    }
    
    [bool] HandleFilter([ParsedCommand]$command) {
        # TODO: Implement filtering logic
        $this.ShowInfo("Filter functionality not yet implemented")
        return $false
    }
    
    [bool] HandleSort([ParsedCommand]$command) {
        # TODO: Implement sorting logic
        $this.ShowInfo("Sort functionality not yet implemented")
        return $false
    }
    
    [bool] HandleExport([ParsedCommand]$command) {
        # TODO: Implement export logic
        $this.ShowInfo("Export functionality not yet implemented")
        return $false
    }
    
    [bool] HandleList([ParsedCommand]$command) {
        $projects = $this.ProjectService.GetAllProjects()
        $activeProjects = $projects | Where-Object { -not $_.Deleted }
        
        $this.ShowInfo("Found $($activeProjects.Count) active projects")
        return $true
    }
    
    [bool] HandleFind([ParsedCommand]$command) {
        $searchTerm = [CommandParser]::GetParameterValue($command, 'name')
        if ([string]::IsNullOrEmpty($searchTerm)) {
            $this.ShowError("Search term required. Usage: :find project name: <search>")
            return $false
        }
        
        $projects = $this.ProjectService.GetAllProjects()
        $matches = $projects | Where-Object { 
            $_.FullProjectName -like "*$searchTerm*" -or 
            $_.ID1 -like "*$searchTerm*" -or 
            $_.ID2 -like "*$searchTerm*"
        }
        
        $this.ShowInfo("Found $($matches.Count) matching projects")
        return $true
    }
    
    [Project] FindProject([ParsedCommand]$command) {
        # Try to find project by ID first (numeric)
        $idParam = [CommandParser]::GetParameterValue($command, 'id')
        if (-not [string]::IsNullOrEmpty($idParam)) {
            $project = $this.ProjectService.GetProject($idParam)
            if ($project) {
                return $project
            }
        }
        
        # Try by name (positional or named parameter)
        $name = [CommandParser]::GetParameterValue($command, 'name')
        if (-not [string]::IsNullOrEmpty($name)) {
            $projects = $this.ProjectService.GetAllProjects()
            $project = $projects | Where-Object { $_.FullProjectName -eq $name } | Select-Object -First 1
            if ($project) {
                return $project
            }
            
            # Try partial match
            $project = $projects | Where-Object { $_.FullProjectName -like "*$name*" } | Select-Object -First 1
            if ($project) {
                return $project
            }
        }
        
        # Try by ID1 or ID2
        $id1 = [CommandParser]::GetParameterValue($command, 'id1')
        if (-not [string]::IsNullOrEmpty($id1)) {
            $projects = $this.ProjectService.GetAllProjects()
            $project = $projects | Where-Object { $_.ID1 -eq $id1 } | Select-Object -First 1
            if ($project) {
                return $project
            }
        }
        
        $this.ShowError("Project not found. Specify id:, name:, or id1: parameter")
        return $null
    }
    
    [void] ShowSuccess([string]$message) {
        if ($this.ToastService) {
            $this.ToastService.ShowToast($message, [ToastType]::Success, 2000)
        }
        if ($this.Logger) {
            $this.Logger.Info($message)
        }
    }
    
    [void] ShowError([string]$message) {
        if ($this.ToastService) {
            $this.ToastService.ShowToast($message, [ToastType]::Error, 3000)
        }
        if ($this.Logger) {
            $this.Logger.Error($message)
        }
    }
    
    [void] ShowWarning([string]$message) {
        if ($this.ToastService) {
            $this.ToastService.ShowToast($message, [ToastType]::Warning, 2500)
        }
        if ($this.Logger) {
            $this.Logger.Warning($message)
        }
    }
    
    [void] ShowInfo([string]$message) {
        if ($this.ToastService) {
            $this.ToastService.ShowToast($message, [ToastType]::Info, 2000)
        }
        if ($this.Logger) {
            $this.Logger.Info($message)
        }
    }
}
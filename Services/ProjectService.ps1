# ProjectService - Business logic for project management
# Lightweight service focusing on project-related operations

class ProjectService {
    hidden [System.Collections.ArrayList]$Projects = [System.Collections.ArrayList]::new()
    hidden [string]$DataFile
    
    ProjectService() {
        # Use PRAXIS data directory
        $praxisDir = if ($global:PraxisRoot) { $global:PraxisRoot } else { $PSScriptRoot }
        $this.DataFile = Join-Path $praxisDir "_ProjectData/projects.json"
        
        # Ensure directory exists
        $dataDir = Split-Path $this.DataFile -Parent
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }
        
        $this.LoadProjects()
    }
    
    [void] LoadProjects() {
        if (Test-Path $this.DataFile) {
            try {
                $json = Get-Content $this.DataFile -Raw
                $data = $json | ConvertFrom-Json
                $this.Projects.Clear()
                foreach ($projData in $data) {
                    # Handle both old and new format
                    if ($projData.PSObject.Properties['FullProjectName']) {
                        # New PMC format
                        $project = [Project]::new($projData.FullProjectName, $projData.Nickname)
                        $project.Id = $projData.Id
                        $project.ID1 = $projData.ID1 ?? ""
                        $project.ID2 = $projData.ID2 ?? ""
                        if ($projData.DateAssigned) { $project.DateAssigned = [DateTime]::Parse($projData.DateAssigned) }
                        if ($projData.BFDate) { $project.BFDate = [DateTime]::Parse($projData.BFDate) }
                        if ($projData.DateDue) { $project.DateDue = [DateTime]::Parse($projData.DateDue) }
                        $project.Note = $projData.Note ?? ""
                        $project.CAAPath = $projData.CAAPath ?? ""
                        $project.RequestPath = $projData.RequestPath ?? ""
                        $project.T2020Path = $projData.T2020Path ?? ""
                        $project.CumulativeHrs = $projData.CumulativeHrs ?? 0
                        if ($projData.ClosedDate -and $projData.ClosedDate -ne "0001-01-01T00:00:00") { 
                            $project.ClosedDate = [DateTime]::Parse($projData.ClosedDate) 
                        }
                        
                        # Load all the new fields
                        $project.Status = $projData.Status ?? "Active"
                        $project.ClientID = $projData.ClientID ?? ""
                        
                        # Audit fields
                        $project.AuditType = $projData.AuditType ?? ""
                        $project.AuditProgram = $projData.AuditProgram ?? ""
                        $project.AuditCase = $projData.AuditCase ?? ""
                        if ($projData.AuditStartDate -and $projData.AuditStartDate -ne "0001-01-01T00:00:00") {
                            $project.AuditStartDate = [DateTime]::Parse($projData.AuditStartDate)
                        }
                        if ($projData.AuditPeriodFrom -and $projData.AuditPeriodFrom -ne "0001-01-01T00:00:00") {
                            $project.AuditPeriodFrom = [DateTime]::Parse($projData.AuditPeriodFrom)
                        }
                        if ($projData.AuditPeriodTo -and $projData.AuditPeriodTo -ne "0001-01-01T00:00:00") {
                            $project.AuditPeriodTo = [DateTime]::Parse($projData.AuditPeriodTo)
                        }
                        
                        # Additional audit periods
                        for ($i = 1; $i -le 5; $i++) {
                            $startProp = "AuditPeriod${i}Start"
                            $endProp = "AuditPeriod${i}End"
                            if ($projData.$startProp -and $projData.$startProp -ne "0001-01-01T00:00:00") {
                                $project.$startProp = [DateTime]::Parse($projData.$startProp)
                            }
                            if ($projData.$endProp -and $projData.$endProp -ne "0001-01-01T00:00:00") {
                                $project.$endProp = [DateTime]::Parse($projData.$endProp)
                            }
                        }
                        
                        # Address fields
                        $project.Address = $projData.Address ?? ""
                        $project.City = $projData.City ?? ""
                        $project.Province = $projData.Province ?? ""
                        $project.PostalCode = $projData.PostalCode ?? ""
                        $project.Country = $projData.Country ?? ""
                        $project.ShipToAddress = $projData.ShipToAddress ?? ""
                        
                        # Auditor fields
                        $project.AuditorName = $projData.AuditorName ?? ""
                        $project.AuditorPhone = $projData.AuditorPhone ?? ""
                        $project.AuditorTL = $projData.AuditorTL ?? ""
                        $project.AuditorTLPhone = $projData.AuditorTLPhone ?? ""
                        
                        # Contact fields
                        $project.Contact1Name = $projData.Contact1Name ?? ""
                        $project.Contact1Phone = $projData.Contact1Phone ?? ""
                        $project.Contact1Ext = $projData.Contact1Ext ?? ""
                        $project.Contact1Address = $projData.Contact1Address ?? ""
                        $project.Contact1Title = $projData.Contact1Title ?? ""
                        $project.Contact2Name = $projData.Contact2Name ?? ""
                        $project.Contact2Phone = $projData.Contact2Phone ?? ""
                        $project.Contact2Ext = $projData.Contact2Ext ?? ""
                        $project.Contact2Address = $projData.Contact2Address ?? ""
                        $project.Contact2Title = $projData.Contact2Title ?? ""
                        
                        # Software fields
                        $project.AccountingSoftware1 = $projData.AccountingSoftware1 ?? ""
                        $project.AccountingSoftware1Other = $projData.AccountingSoftware1Other ?? ""
                        $project.AccountingSoftware1Type = $projData.AccountingSoftware1Type ?? ""
                        $project.AccountingSoftware2 = $projData.AccountingSoftware2 ?? ""
                        $project.AccountingSoftware2Other = $projData.AccountingSoftware2Other ?? ""
                        $project.AccountingSoftware2Type = $projData.AccountingSoftware2Type ?? ""
                        
                        # Other fields
                        if ($projData.RequestDate -and $projData.RequestDate -ne "0001-01-01T00:00:00") {
                            $project.RequestDate = [DateTime]::Parse($projData.RequestDate)
                        }
                        $project.FXInfo = $projData.FXInfo ?? ""
                        $project.Comments = $projData.Comments ?? ""
                        
                        $project.Deleted = $projData.Deleted ?? $false
                    } else {
                        # Legacy format
                        $project = [Project]::new($projData.Name)
                        $project.Id = $projData.Id
                        if ($projData.Description) { $project.Note = $projData.Description }
                    }
                    $this.Projects.Add($project) | Out-Null
                }
            }
            catch {
                Write-Error "Failed to load projects: $_"
            }
        }
        
        # Ensure default project exists
        if (-not ($this.Projects | Where-Object { $_.Nickname -eq "Default" })) {
            $default = [Project]::new("Default")
            $default.Note = "Default project for uncategorized tasks"
            $this.Projects.Add($default) | Out-Null
            $this.SaveProjects()
        }
    }
    
    [void] SaveProjects() {
        $dir = Split-Path $this.DataFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        $data = @()
        foreach ($project in $this.Projects) {
            $data += @{
                Id = $project.Id
                FullProjectName = $project.FullProjectName
                Nickname = $project.Nickname
                ID1 = $project.ID1
                ID2 = $project.ID2
                DateAssigned = $project.DateAssigned.ToString("yyyy-MM-ddTHH:mm:ss")
                BFDate = $project.BFDate.ToString("yyyy-MM-ddTHH:mm:ss")
                DateDue = $project.DateDue.ToString("yyyy-MM-ddTHH:mm:ss")
                Note = $project.Note
                CAAPath = $project.CAAPath
                RequestPath = $project.RequestPath
                T2020Path = $project.T2020Path
                CumulativeHrs = $project.CumulativeHrs
                ClosedDate = $project.ClosedDate.ToString("yyyy-MM-ddTHH:mm:ss")
                Deleted = $project.Deleted
            }
        }
        
        $json = $data | ConvertTo-Json -Depth 10
        Set-Content -Path $this.DataFile -Value $json
    }
    
    [Project[]] GetAllProjects() {
        return $this.Projects.ToArray()
    }
    
    [Project] GetProject([string]$id) {
        return $this.Projects | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    }
    
    [Project] GetProjectByName([string]$name) {
        return $this.Projects | Where-Object { $_.Nickname -eq $name -or $_.FullProjectName -eq $name } | Select-Object -First 1
    }
    
    [Project] AddProject([string]$name) {
        # Check if already exists
        $existing = $this.GetProjectByName($name)
        if ($existing) {
            return $existing
        }
        
        $project = [Project]::new($name)
        $this.Projects.Add($project) | Out-Null
        $this.SaveProjects()
        return $project
    }
    
    [Project] AddProject([string]$fullName, [string]$nickname) {
        # Check if already exists
        $existing = $this.GetProjectByName($nickname)
        if ($existing) {
            return $existing
        }
        
        $project = [Project]::new($fullName, $nickname)
        $this.Projects.Add($project) | Out-Null
        $this.SaveProjects()
        return $project
    }
    
    [Project] AddProject([Project]$project) {
        # Check if already exists by nickname
        $existing = $this.GetProjectByName($project.Nickname)
        if ($existing) {
            return $existing
        }
        
        $this.Projects.Add($project) | Out-Null
        $this.SaveProjects()
        return $project
    }
    
    [void] UpdateProject([Project]$project) {
        $this.SaveProjects()
    }
    
    [void] DeleteProject([string]$id) {
        $project = $this.GetProject($id)
        if ($project -and $project.Nickname -ne "Default") {
            $this.Projects.Remove($project)
            $this.SaveProjects()
        }
    }
    
    [hashtable[]] GetProjectsWithStats([object]$taskService) {
        $result = @()
        
        foreach ($project in $this.Projects) {
            $tasks = $taskService.GetTasksByProject($project.Nickname)
            $completed = ($tasks | Where-Object { $_.Status -eq "Done" }).Count
            $total = $tasks.Count
            
            $result += @{
                Project = $project
                Name = $project.Nickname  # Use nickname for compatibility
                FullName = $project.FullProjectName
                TaskCount = $total
                CompletedCount = $completed
                Progress = if ($total -gt 0) { $completed / $total } else { 0 }
            }
        }
        
        return $result
    }
}
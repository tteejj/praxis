# Debug script to see what data is actually being loaded
$global:PraxisRoot = $PSScriptRoot

# Load minimal dependencies
. "$PSScriptRoot/Models/Project.ps1"
. "$PSScriptRoot/Services/ProjectService.ps1"

try {
    Write-Host "=== DEBUG: Checking if projects exist ===" -ForegroundColor Yellow
    
    # Create project service
    $projectService = [ProjectService]::new()
    
    # Get all projects
    $projects = $projectService.GetAllProjects()
    Write-Host "Total projects found: $($projects.Count)" -ForegroundColor Green
    
    if ($projects.Count -eq 0) {
        Write-Host "PROBLEM: No projects exist! Creating test project..." -ForegroundColor Red
        
        # Create a test project
        $testProject = [Project]::new()
        $testProject.Name = "Test Project"
        $testProject.ID1 = "TEST"
        $testProject.ID2 = "TEST001"
        $testProject.Nickname = "Test"
        $testProject.Deleted = $false
        
        $projectService.CreateProject($testProject)
        Write-Host "Created test project: $($testProject.Name)" -ForegroundColor Green
        
        # Check again
        $projects = $projectService.GetAllProjects()
        Write-Host "Projects after creation: $($projects.Count)" -ForegroundColor Green
    }
    
    # Show project details
    foreach ($project in $projects) {
        Write-Host "Project: $($project.Name) | ID2: $($project.ID2) | Deleted: $($project.Deleted)" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
}
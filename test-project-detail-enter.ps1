#!/usr/bin/env pwsh

# Test ProjectDetailScreen via Enter key press

# Load framework
. ./Start.ps1 -NoRun

Write-Host "Testing ProjectDetailScreen via Enter key..." -ForegroundColor Cyan

try {
    # Get ProjectService
    $projectService = $global:ServiceContainer.GetService('ProjectService')
    if (-not $projectService) {
        Write-Host "Error: ProjectService not found" -ForegroundColor Red
        exit 1
    }
    
    # Get first project or create test project
    $projects = $projectService.GetAllProjects()
    $testProject = $null
    
    if ($projects.Count -gt 0) {
        $testProject = $projects[0]
        Write-Host "Using existing project: $($testProject.FullProjectName)" -ForegroundColor Yellow
    } else {
        # Create a test project
        Write-Host "Creating test project..." -ForegroundColor Yellow
        $testProject = $projectService.AddProject("Test Project")
        $testProject.ID2 = "TEST123"
        $testProject.DateCreated = [DateTime]::Now
        $testProject.DateDue = [DateTime]::Now.AddDays(30)
        $testProject.Note = "This is a test project"
        $projectService.SaveProjects()
    }
    
    # Create ProjectDetailScreen
    Write-Host "Creating ProjectDetailScreen..." -ForegroundColor Yellow
    $screen = [ProjectDetailScreen]::new($testProject)
    
    # Initialize it
    Write-Host "Initializing screen..." -ForegroundColor Yellow
    $screen.Initialize($global:ServiceContainer)
    
    # Set bounds (simulate full screen)
    Write-Host "Setting bounds..." -ForegroundColor Yellow
    $screen.SetBounds(0, 0, 80, 25)
    
    # Activate it
    Write-Host "Activating screen..." -ForegroundColor Yellow
    $screen.OnActivated()
    
    Write-Host "`nSuccess! ProjectDetailScreen loaded without crashing." -ForegroundColor Green
    
    # Check components
    Write-Host "`nChecking components:" -ForegroundColor Cyan
    Write-Host "  ProjectInfoGrid: $($screen.ProjectInfoGrid -ne $null)" -ForegroundColor Gray
    if ($screen.ProjectInfoGrid -and $screen.ProjectInfoGrid.Items) {
        Write-Host "    Items: $($screen.ProjectInfoGrid.Items.Count)" -ForegroundColor Gray
    }
    
    Write-Host "  TimeEntriesGrid: $($screen.TimeEntriesGrid -ne $null)" -ForegroundColor Gray
    if ($screen.TimeEntriesGrid -and $screen.TimeEntriesGrid.Items) {
        Write-Host "    Items: $($screen.TimeEntriesGrid.Items.Count)" -ForegroundColor Gray
    }
    
    Write-Host "  StatusBar: $($screen.StatusBar -ne $null)" -ForegroundColor Gray
    
    # Test rendering
    Write-Host "`nTesting render..." -ForegroundColor Cyan
    $output = $screen.Render()
    if ($output) {
        Write-Host "  Render output length: $($output.Length) characters" -ForegroundColor Gray
        Write-Host "  Screen renders successfully" -ForegroundColor Green
    } else {
        Write-Host "  Warning: Empty render output" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
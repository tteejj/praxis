#!/usr/bin/env pwsh
# Test CRUD refresh behavior

. ./Start.ps1 -NoRun

Write-Host "Testing CRUD refresh behavior..." -ForegroundColor Cyan

# Initialize services
$container = [ServiceContainer]::new()
InitializeServices $container

# Get services
$eventBus = $container.GetService('EventBus')
$projectService = $container.GetService('ProjectService')
$taskService = $container.GetService('TaskService')

# Enable debug logging
$eventBus.EnableDebugLogging = $true

# Create test screen
$projectsScreen = [ProjectsScreen]::new()
$projectsScreen.Initialize($container)

Write-Host "`nInitial project count: $($projectsScreen.ProjectGrid.Items.Count)" -ForegroundColor Yellow

# Test project creation event
Write-Host "`nTesting project creation event..." -ForegroundColor Green
$newProject = $projectService.AddProject("Test Project $(Get-Date -Format 'HHmmss')")
$eventBus.Publish([EventNames]::ProjectCreated, @{ Project = $newProject })

Start-Sleep -Milliseconds 100
Write-Host "Project count after creation event: $($projectsScreen.ProjectGrid.Items.Count)" -ForegroundColor Yellow

# Test project deletion event
Write-Host "`nTesting project deletion event..." -ForegroundColor Green
$projectToDelete = $projectsScreen.ProjectGrid.Items[0]
if ($projectToDelete) {
    Write-Host "Deleting project: $($projectToDelete.FullProjectName)" -ForegroundColor Gray
    $projectService.DeleteProject($projectToDelete.Id)
    $eventBus.Publish([EventNames]::ProjectDeleted, @{ ProjectId = $projectToDelete.Id })
    
    Start-Sleep -Milliseconds 100
    Write-Host "Project count after deletion event: $($projectsScreen.ProjectGrid.Items.Count)" -ForegroundColor Yellow
}

# Test task screen
Write-Host "`n`nTesting Task Screen..." -ForegroundColor Cyan
$taskScreen = [TaskScreen]::new()
$taskScreen.Initialize($container)

Write-Host "Initial task count: $($taskScreen.TaskGrid.Items.Count)" -ForegroundColor Yellow

# Test task creation event
Write-Host "`nTesting task creation event..." -ForegroundColor Green
$newTask = $taskService.CreateTask(@{
    Title = "Test Task $(Get-Date -Format 'HHmmss')"
    Description = "Test Description"
    Priority = [TaskPriority]::Medium
})
$eventBus.Publish([EventNames]::TaskCreated, @{ Task = $newTask })

Start-Sleep -Milliseconds 100
Write-Host "Task count after creation event: $($taskScreen.TaskGrid.Items.Count)" -ForegroundColor Yellow

# Test task deletion event
Write-Host "`nTesting task deletion event..." -ForegroundColor Green
$taskToDelete = $taskScreen.TaskGrid.Items[0]
if ($taskToDelete) {
    Write-Host "Deleting task: $($taskToDelete.Title)" -ForegroundColor Gray
    $taskService.DeleteTask($taskToDelete.Id)
    $eventBus.Publish([EventNames]::TaskDeleted, @{ TaskId = $taskToDelete.Id })
    
    Start-Sleep -Milliseconds 100
    Write-Host "Task count after deletion event: $($taskScreen.TaskGrid.Items.Count)" -ForegroundColor Yellow
}

Write-Host "`n`nEvent history:" -ForegroundColor Cyan
$eventBus.GetEventHistory() | ForEach-Object {
    Write-Host "  - $($_.EventName) at $($_.Timestamp)" -ForegroundColor Gray
}

Write-Host "`nTest completed!" -ForegroundColor Green
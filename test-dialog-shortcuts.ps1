#!/usr/bin/env pwsh
# Test script to verify dialog shortcuts work without errors

$ErrorActionPreference = "Stop"

Write-Host "Testing Dialog Shortcuts..." -ForegroundColor Green

# Load components directly without starting UI
$ErrorActionPreference = "Stop"

# Load all required files in correct order
$files = @(
    "Core/ServiceContainer.ps1",
    "Core/StringBuilderPool.ps1",
    "Core/StringCache.ps1",
    "Core/VT100.ps1",
    "Core/BorderStyle.ps1",
    "Base/UIElement.ps1",
    "Base/Container.ps1",
    "Base/FocusableComponent.ps1",
    "Base/Screen.ps1",
    "Base/BaseDialog.ps1",
    "Components/MinimalButton.ps1",
    "Components/MinimalTextBox.ps1",
    "Components/MinimalListBox.ps1",
    "Components/MinimalDataGrid.ps1",
    "Models/Project.ps1",
    "Models/Task.ps1",
    "Services/ProjectService.ps1",
    "Services/TaskService.ps1",
    "Services/SubtaskService.ps1",
    "Services/EventBus.ps1",
    "Services/ThemeManager.ps1",
    "Services/Logger.ps1",
    "Screens/NewProjectDialog.ps1",
    "Screens/EditProjectDialog.ps1", 
    "Screens/ConfirmationDialog.ps1",
    "Screens/NewTaskDialog.ps1",
    "Screens/EditTaskDialog.ps1",
    "Screens/SubtaskDialog.ps1",
    "Screens/ProjectsScreen.ps1",
    "Screens/TaskScreen.ps1"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        . ./$file
    }
}

# Create minimal service container
$global:ServiceContainer = [ServiceContainer]::new()
$global:ServiceContainer.RegisterService('Logger', [Logger]::new())
$global:ServiceContainer.RegisterService('EventBus', [EventBus]::new())
$global:ServiceContainer.RegisterService('ThemeManager', [ThemeManager]::new())
$global:ServiceContainer.RegisterService('ProjectService', [ProjectService]::new())
$global:ServiceContainer.RegisterService('TaskService', [TaskService]::new())
$global:ServiceContainer.RegisterService('SubtaskService', [SubtaskService]::new())

# Simulate being on ProjectsScreen
Write-Host "`nSimulating ProjectsScreen..." -ForegroundColor Yellow
$projectsScreen = [ProjectsScreen]::new()
$projectsScreen.Initialize($global:ServiceContainer)

# Test N key (NewProjectDialog)
Write-Host "Testing N key (New Project)..." -ForegroundColor Cyan
try {
    $projectsScreen.NewProject()
    Write-Host "✓ NewProject() executed successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ NewProject() failed: $_" -ForegroundColor Red
}

# Test E key (EditProjectDialog) - need a project first
Write-Host "`nTesting E key (Edit Project)..." -ForegroundColor Cyan
try {
    # Add a dummy project to the grid
    $project = [Project]::new("Test Project")
    $projectsScreen.ProjectGrid.SetItems(@($project))
    $projectsScreen.ProjectGrid.SelectIndex(0)
    
    $projectsScreen.EditProject()
    Write-Host "✓ EditProject() executed successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ EditProject() failed: $_" -ForegroundColor Red
}

# Test D key (DeleteProject with ConfirmationDialog)
Write-Host "`nTesting D key (Delete Project)..." -ForegroundColor Cyan
try {
    $projectsScreen.DeleteProject()
    Write-Host "✓ DeleteProject() executed successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ DeleteProject() failed: $_" -ForegroundColor Red
}

# Simulate being on TaskScreen
Write-Host "`n`nSimulating TaskScreen..." -ForegroundColor Yellow
$taskScreen = [TaskScreen]::new()
$taskScreen.Initialize($global:ServiceContainer)

# Test N key (NewTaskDialog)
Write-Host "Testing N key (New Task)..." -ForegroundColor Cyan
try {
    $taskScreen.NewTask()
    Write-Host "✓ NewTask() executed successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ NewTask() failed: $_" -ForegroundColor Red
}

# Test E key (EditTaskDialog) - need a task first
Write-Host "`nTesting E key (Edit Task)..." -ForegroundColor Cyan
try {
    # Add a dummy task to the grid
    $task = [Task]::new()
    $task.Title = "Test Task"
    $taskScreen.TaskGrid.SetItems(@($task))
    $taskScreen.TaskGrid.SelectIndex(0)
    
    $taskScreen.EditTask()
    Write-Host "✓ EditTask() executed successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ EditTask() failed: $_" -ForegroundColor Red
}

# Test D key (DeleteTask with ConfirmationDialog)
Write-Host "`nTesting D key (Delete Task)..." -ForegroundColor Cyan
try {
    $taskScreen.DeleteTask()
    Write-Host "✓ DeleteTask() executed successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ DeleteTask() failed: $_" -ForegroundColor Red
}

# Test A key (SubtaskDialog)
Write-Host "`nTesting Shift+A key (Add Subtask)..." -ForegroundColor Cyan
try {
    $taskScreen.AddSubtask()
    Write-Host "✓ AddSubtask() executed successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ AddSubtask() failed: $_" -ForegroundColor Red
}

Write-Host "`n`nAll dialog shortcut tests completed!" -ForegroundColor Green
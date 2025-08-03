#!/usr/bin/env pwsh
# Direct test to open new project dialog

. ./Start.ps1 -LoadOnly

# Get screen manager and push main screen
$screenManager = $global:ServiceContainer.GetService('ScreenManager')
$mainScreen = [MainScreen]::new()
$screenManager.Push($mainScreen)

# Wait a moment then trigger new project dialog
Start-Sleep -Milliseconds 100

# Access the projects screen and trigger new project
$projectsScreen = $mainScreen.TabContainer.GetTabByName("Projects").Content
if ($projectsScreen) {
    Write-Host "Opening New Project dialog..." -ForegroundColor Yellow
    $projectsScreen.NewProject()
    
    # Run the screen manager to see the dialog
    $screenManager.Run()
} else {
    Write-Host "Could not find Projects screen!" -ForegroundColor Red
}
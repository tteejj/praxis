#!/usr/bin/env pwsh

# Test ProjectDetailScreen directly

# Load framework
. ./Start.ps1 -NoRun

Write-Host "Testing ProjectDetailScreen..." -ForegroundColor Cyan

try {
    # Create a test project
    $project = [Project]::new()
    $project.Id = "TEST001"
    $project.FullProjectName = "Test Project"
    $project.DateCreated = [DateTime]::Now
    $project.DateDue = [DateTime]::Now.AddDays(30)
    $project.Note = "This is a test project"
    
    # Create ProjectDetailScreen
    Write-Host "Creating ProjectDetailScreen..." -ForegroundColor Yellow
    $screen = [ProjectDetailScreen]::new($project)
    
    # Initialize it
    Write-Host "Initializing screen..." -ForegroundColor Yellow
    $screen.Initialize($global:ServiceContainer)
    
    Write-Host "Success! ProjectDetailScreen created and initialized." -ForegroundColor Green
    
    # Check components
    Write-Host "`nChecking components:" -ForegroundColor Cyan
    Write-Host "  ProjectInfoGrid: $($screen.ProjectInfoGrid -ne $null)" -ForegroundColor Gray
    Write-Host "  TimeEntriesGrid: $($screen.TimeEntriesGrid -ne $null)" -ForegroundColor Gray
    Write-Host "  StatusBar: $($screen.StatusBar -ne $null)" -ForegroundColor Gray
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
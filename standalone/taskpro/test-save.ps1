#!/usr/bin/env pwsh

# Test script to debug the save issue
$global:Debug = $true

# Load required classes
. "$PSScriptRoot/Models/SimpleTask.ps1"
. "$PSScriptRoot/Services/SimpleTaskService.ps1"

# Create a new task service
$service = [SimpleTaskService]::new()

# Create a new task like the UI does
$newTask = [SimpleTask]::new("")
$newTask.Title = "Test Task From Script"
$newTask.Priority = "High"
$newTask.DueDate = (Get-Date).AddDays(1)

Write-Host "Created task:" -ForegroundColor Yellow
Write-Host "  ID: $($newTask.Id)" -ForegroundColor Cyan
Write-Host "  Title: '$($newTask.Title)'" -ForegroundColor Cyan
Write-Host "  Priority: $($newTask.Priority)" -ForegroundColor Cyan
Write-Host "  IsNewTask: True (simulated)" -ForegroundColor Cyan

Write-Host "`nCalling AddTask..." -ForegroundColor Yellow
$service.AddTask($newTask)

Write-Host "Task added successfully!" -ForegroundColor Green

# Verify it was saved by loading fresh service
$verifyService = [SimpleTaskService]::new()
$allTasks = $verifyService.GetParentTasks()

Write-Host "`nAll parent tasks:" -ForegroundColor Yellow
foreach ($task in $allTasks) {
    Write-Host "  $($task.Title) (ID: $($task.Id))" -ForegroundColor Cyan
}
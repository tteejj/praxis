#!/usr/bin/env pwsh
# Test script to verify project settings fixes

# Change to script directory
Set-Location $PSScriptRoot/simpletaskpro

# Import required modules
. ./Core/VT100.ps1
. ./Models/SimpleTask.ps1
. ./Services/SimpleTaskService.ps1
. ./Dialogs/ProjectSettingsDialog.ps1

Write-Host "=== Testing Project Settings Fixes ===" -ForegroundColor Green

# Create a test task
$testTask = [SimpleTask]::new("Test Project Settings")
$testTask.ProjectFolderPath = "/home/teej/test-folder"
$testTask.T2020CallLogFile = "/home/teej/test-t2020.txt"
$testTask.ExportDataFile = "/home/teej/test-export.txt"
$testTask.ActionLogName = "test-action-log"
$testTask.ID1 = "TST"
$testTask.ID2 = "TEST-2025-001"

Write-Host "Initial task values:" -ForegroundColor Yellow
Write-Host "  ProjectFolderPath: '$($testTask.ProjectFolderPath)'" 
Write-Host "  T2020CallLogFile: '$($testTask.T2020CallLogFile)'"
Write-Host "  ExportDataFile: '$($testTask.ExportDataFile)'"
Write-Host "  ActionLogName: '$($testTask.ActionLogName)'"
Write-Host "  ID1: '$($testTask.ID1)'"
Write-Host "  ID2: '$($testTask.ID2)'"

# Create dialog
$dialog = [ProjectSettingsDialog]::new()

# Initialize dialog fields
Write-Host "`nTesting field initialization..." -ForegroundColor Yellow
$dialog.Task = $testTask
$dialog.ProjectFolder = $testTask.ProjectFolderPath
$dialog.T2020File = $testTask.T2020CallLogFile
$dialog.ExportFile = $testTask.ExportDataFile
$dialog.ActionLogName = $testTask.ActionLogName
$dialog.ID1 = $testTask.ID1
$dialog.ID2 = $testTask.ID2

# Test GetFieldValue method
Write-Host "`nTesting GetFieldValue method:" -ForegroundColor Yellow
for ($i = 0; $i -lt 6; $i++) {
    $value = $dialog.GetFieldValue($i)
    $fieldName = @("ProjectFolder", "T2020File", "ExportFile", "ActionLogName", "ID1", "ID2")[$i]
    Write-Host "  Field $i ($($fieldName)): '$value'"
}

# Test ValidateAndSave
Write-Host "`nTesting ValidateAndSave method..." -ForegroundColor Yellow
$result = $dialog.ValidateAndSave()
Write-Host "Save result: $result"

Write-Host "`nFinal task values after save:" -ForegroundColor Yellow
Write-Host "  ProjectFolderPath: '$($testTask.ProjectFolderPath)'" 
Write-Host "  T2020CallLogFile: '$($testTask.T2020CallLogFile)'"
Write-Host "  ExportDataFile: '$($testTask.ExportDataFile)'"
Write-Host "  ActionLogName: '$($testTask.ActionLogName)'"
Write-Host "  ID1: '$($testTask.ID1)'"
Write-Host "  ID2: '$($testTask.ID2)'"

Write-Host "`n=== Test Complete ===" -ForegroundColor Green
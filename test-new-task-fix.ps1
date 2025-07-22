#!/usr/bin/env pwsh
# Test script to verify the new task dialog fix

Write-Host "New Task Dialog Fix Verification" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check that the TaskScreen has the proper variable capture
$content = Get-Content "Screens/TaskScreen.ps1" -Raw

$fixesFound = 0

# Check for $screen capture in NewTask
if ($content -match '\$screen = \$this[\s\S]*\$screen\.TaskService\.CreateTask') {
    Write-Host "✓ NewTask method properly captures \$screen reference" -ForegroundColor Green
    $fixesFound++
} else {
    Write-Host "✗ NewTask method does NOT properly capture \$screen reference" -ForegroundColor Red
}

# Check for $screen capture in EditTask
if ($content -match 'EditTask[\s\S]*\$screen = \$this[\s\S]*\$screen\.TaskService\.UpdateTask') {
    Write-Host "✓ EditTask method properly captures \$screen reference" -ForegroundColor Green
    $fixesFound++
} else {
    Write-Host "✗ EditTask method does NOT properly capture \$screen reference" -ForegroundColor Red
}

# Check for $screen capture in DeleteTask
if ($content -match 'DeleteTask[\s\S]*\$screen = \$this[\s\S]*\$screen\.TaskService\.DeleteTask') {
    Write-Host "✓ DeleteTask method properly captures \$screen reference" -ForegroundColor Green
    $fixesFound++
} else {
    Write-Host "✗ DeleteTask method does NOT properly capture \$screen reference" -ForegroundColor Red
}

Write-Host ""
Write-Host "Results: $fixesFound/3 fixes verified" -ForegroundColor $(if ($fixesFound -eq 3) { "Green" } else { "Yellow" })

if ($fixesFound -eq 3) {
    Write-Host ""
    Write-Host "All null reference fixes have been applied!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To test the fix:" -ForegroundColor Cyan
    Write-Host "1. Run: pwsh -File Start.ps1"
    Write-Host "2. Press '2' to go to Tasks tab"
    Write-Host "3. Press 'n' to create a new task"
    Write-Host "4. Fill in the task details and press Tab to navigate to Create button"
    Write-Host "5. Press Enter to create the task"
    Write-Host ""
    Write-Host "The task should be created without any null reference errors." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Some fixes are missing. Please review the TaskScreen.ps1 file." -ForegroundColor Yellow
}
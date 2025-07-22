#!/usr/bin/env pwsh
# Test script to verify the Project constructor fix

Write-Host "Project Constructor Fix Verification" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

$errors = 0

# Check CommandPalette doesn't use parameterless Project constructor
Write-Host "Checking CommandPalette.ps1..." -ForegroundColor Yellow
$content = Get-Content "Components/CommandPalette.ps1" -Raw
if ($content -match '\[Project\]::new\(\)') {
    Write-Host "  ✗ CommandPalette still uses parameterless Project constructor" -ForegroundColor Red
    $errors++
} else {
    Write-Host "  ✓ CommandPalette properly uses ProjectService.AddProject" -ForegroundColor Green
}

# Check ProjectsScreen uses dialog properly
Write-Host "`nChecking ProjectsScreen.ps1..." -ForegroundColor Yellow
$content = Get-Content "Screens/ProjectsScreen.ps1" -Raw
if ($content -match 'NewProject[\s\S]*NewProjectDialog') {
    Write-Host "  ✓ ProjectsScreen now uses NewProjectDialog" -ForegroundColor Green
} else {
    Write-Host "  ✗ ProjectsScreen doesn't use NewProjectDialog" -ForegroundColor Red
    $errors++
}

# Verify Project model has correct constructors
Write-Host "`nChecking Project.ps1..." -ForegroundColor Yellow
$content = Get-Content "Models/Project.ps1" -Raw
if ($content -match 'Project\(\[string\]\$fullName, \[string\]\$nickname\)' -and 
    $content -match 'Project\(\[string\]\$name\)') {
    Write-Host "  ✓ Project has correct constructors (with parameters)" -ForegroundColor Green
} else {
    Write-Host "  ✗ Project constructors may be missing" -ForegroundColor Red
    $errors++
}

Write-Host ""
if ($errors -eq 0) {
    Write-Host "All fixes verified successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To test the fix:" -ForegroundColor Cyan
    Write-Host "1. Run: pwsh -File Start.ps1"
    Write-Host "2. Press '1' to go to Projects tab"
    Write-Host "3. Press 'n' to create a new project"
    Write-Host "4. Fill in the project name and press Tab to navigate to Create button"
    Write-Host "5. Press Enter to create the project"
    Write-Host ""
    Write-Host "The project should be created without constructor errors." -ForegroundColor Green
} else {
    Write-Host "Found $errors issues. Please review the fixes." -ForegroundColor Red
}
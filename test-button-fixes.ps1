#!/usr/bin/env pwsh
# Test script to verify button fixes in dialogs

Write-Host "Button Fix Verification Script" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will verify that the button fixes have been applied correctly."
Write-Host ""

# Read the dialog files and check for the button fix patterns
$dialogFiles = @(
    "Screens/NewProjectDialog.ps1",
    "Screens/NewTaskDialog.ps1", 
    "Screens/EditTaskDialog.ps1",
    "Screens/ConfirmationDialog.ps1"
)

$fixesFound = 0
$totalChecks = $dialogFiles.Count * 3  # 3 checks per file

foreach ($file in $dialogFiles) {
    Write-Host "`nChecking $file..." -ForegroundColor Yellow
    $content = Get-Content $file -Raw
    
    # Check 1: OnBoundsChanged method exists
    if ($content -match "OnBoundsChanged\(\)") {
        Write-Host "  ✓ OnBoundsChanged method found" -ForegroundColor Green
        $fixesFound++
    } else {
        Write-Host "  ✗ OnBoundsChanged method NOT found" -ForegroundColor Red
    }
    
    # Check 2: Button positioning logic similar to ProjectsScreen
    if ($content -match "buttonHeight = 3" -and $content -match "buttonSpacing = 2" -and $content -match "maxButtonWidth") {
        Write-Host "  ✓ Button positioning logic found" -ForegroundColor Green
        $fixesFound++
    } else {
        Write-Host "  ✗ Button positioning logic NOT found" -ForegroundColor Red
    }
    
    # Check 3: Dark overlay rendering
    if ($content -match "Dark gray overlay" -or $content -match "RGBBG\(16, 16, 16\)") {
        Write-Host "  ✓ Dark overlay rendering found" -ForegroundColor Green
        $fixesFound++
    } else {
        Write-Host "  ✗ Dark overlay rendering NOT found" -ForegroundColor Red
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Results: $fixesFound/$totalChecks checks passed" -ForegroundColor $(if ($fixesFound -eq $totalChecks) { "Green" } else { "Yellow" })

if ($fixesFound -eq $totalChecks) {
    Write-Host "`nAll button fixes have been successfully applied!" -ForegroundColor Green
} else {
    Write-Host "`nSome fixes may be missing. Please review the files." -ForegroundColor Yellow
}

Write-Host "`nTo test the dialogs manually:" -ForegroundColor Cyan
Write-Host "1. Run: pwsh -File Start.ps1"
Write-Host "2. Press '2' to go to Tasks tab"
Write-Host "3. Press 'n' to open New Task dialog"
Write-Host "4. Check that buttons are properly centered and rendered"
Write-Host "5. Use Tab to navigate between buttons"
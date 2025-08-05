#!/usr/bin/env pwsh

Write-Host "Testing Enter key flow with logging..." -ForegroundColor Green

# Load all dependencies
. "$PSScriptRoot/Core/VT100.ps1"
. "$PSScriptRoot/Base/SimpleDialog.ps1"
. "$PSScriptRoot/Services/ConfigurationService.ps1"
. "$PSScriptRoot/Services/ExportProfileService.ps1"
. "$PSScriptRoot/Services/TextExportService.ps1"
. "$PSScriptRoot/Screens/StartupSelectionDialog.ps1"
. "$PSScriptRoot/Screens/ProfileSelectionDialog.ps1"

# Simulate the workflow
Write-Host "`n1. Creating StartupSelectionDialog..." -ForegroundColor Cyan
$startupDialog = [StartupSelectionDialog]::new()

# Set up workflow event (like IntegratedWorkflowManager does)
$startupDialog.OnSelect = {
    Write-Host "`n=== StartupDialog.OnSelect triggered ===" -ForegroundColor Magenta
    switch ($startupDialog.SelectedIndex) {
        0 { $startupDialog.SelectedOption = "profile" }
        1 { $startupDialog.SelectedOption = "configure" }
    }
    Write-Host "Selected option set to: $($startupDialog.SelectedOption)" -ForegroundColor Yellow
    
    if ($startupDialog.SelectedOption -eq "profile") {
        Write-Host "Starting profile export simulation..." -ForegroundColor Green
        
        # Create ProfileSelectionDialog (like the workflow does)
        Write-Host "`n2. Creating ProfileSelectionDialog..." -ForegroundColor Cyan
        $profileDialog = [ProfileSelectionDialog]::new()
        
        # Set up profile dialog events
        $profileDialog.OnSelect = {
            Write-Host "`n=== ProfileDialog.OnSelect triggered ===" -ForegroundColor Magenta
            Write-Host "Selected Profile: '$($profileDialog.SelectedProfile)'" -ForegroundColor Yellow
            $profileDialog.DialogResult = $true
            Write-Host "Profile DialogResult set to true" -ForegroundColor Green
        }.GetNewClosure()
        
        Write-Host "Profile dialog setup complete. In real app, this would show the dialog." -ForegroundColor Green
        Write-Host "Selected profile: '$($profileDialog.SelectedProfile)'" -ForegroundColor Cyan
    }
}.GetNewClosure()

Write-Host "`nStartup dialog setup complete." -ForegroundColor Green
Write-Host "Selected option: '$($startupDialog.SelectedOption)'" -ForegroundColor Cyan
Write-Host "Selected index: $($startupDialog.SelectedIndex)" -ForegroundColor Cyan

Write-Host "`n✅ Test setup complete - this shows the workflow structure" -ForegroundColor Green
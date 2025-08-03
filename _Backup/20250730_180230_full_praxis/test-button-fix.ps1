#!/usr/bin/env pwsh
Write-Host "Testing button rendering..." -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

# Create new project dialog
$dialog = [NewProjectDialog]::new()
$dialog.Initialize($global:ServiceContainer)
$dialog.SetBounds(10, 5, 60, 22)

Write-Host "Dialog buttons:" -ForegroundColor Cyan
Write-Host "Primary: '$($dialog.PrimaryButton.Text)'" -ForegroundColor Green
Write-Host "Secondary: '$($dialog.SecondaryButton.Text)'" -ForegroundColor Green

# Test button layout
$layout = $dialog._buttonLayout
if ($layout) {
    Write-Host "`nButton layout type: $($layout.GetType().Name)" -ForegroundColor Cyan
    Write-Host "Left pane: $($layout.LeftPane.Text)" -ForegroundColor Green
    Write-Host "Right pane: $($layout.RightPane.Text)" -ForegroundColor Green
}

Write-Host "`nButtons should show 'Create' and 'Cancel' with proper spacing." -ForegroundColor Yellow

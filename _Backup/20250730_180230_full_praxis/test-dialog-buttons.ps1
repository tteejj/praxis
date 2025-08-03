#!/usr/bin/env pwsh
Write-Host "Testing dialog buttons..." -ForegroundColor Yellow

. ./Start.ps1 -LoadOnly

# Create a test dialog
$dialog = [NewProjectDialog]::new()
$dialog.Initialize($global:ServiceContainer)

Write-Host "Primary button text: '$($dialog.PrimaryButton.Text)'" -ForegroundColor Cyan
Write-Host "Secondary button text: '$($dialog.SecondaryButton.Text)'" -ForegroundColor Cyan

Write-Host "`nButtons should show 'Create' and 'Cancel' with proper spacing." -ForegroundColor Green

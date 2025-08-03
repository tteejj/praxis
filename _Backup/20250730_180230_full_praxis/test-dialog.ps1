#!/usr/bin/env pwsh
# Test dialog rendering

. ./Start.ps1 -LoadOnly

# Create and show a test dialog
$dialog = [NewProjectDialog]::new()
$dialog.Initialize($global:ServiceContainer)
$dialog.SetBounds(10, 5, 60, 22)

# Render the dialog
Write-Host "`nDialog rendering test:" -ForegroundColor Yellow
$content = $dialog.Render()

# Display a portion of the rendered dialog
Write-Host $content

Write-Host "`nDialog button area should show 'Create' and 'Cancel' properly spaced." -ForegroundColor Green
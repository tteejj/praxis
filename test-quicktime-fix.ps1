#!/usr/bin/env pwsh

# Test script for Quick Time Entry dialog fix
. "$PSScriptRoot/Start.ps1" -LoadOnly

# Create a minimal test to see the dialog
$screenManager = $global:ServiceContainer.GetService('ScreenManager')
$dialog = [QuickTimeEntryDialog]::new([DateTime]::Now)

Write-Host "Testing Quick Time Entry Dialog..."
Write-Host "Opening dialog - press Escape to close, Ctrl+C to exit completely"

# Push the dialog onto the screen stack
$screenManager.Push($dialog)

# Run for a few seconds to see the result
$screenManager.Run()
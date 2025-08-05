#!/usr/bin/env pwsh
# Test script for CommandEditDialog fixes

# Load the CommandLibrary
. "$PSScriptRoot/CommandLibrary/CommandLibrary.ps1"

Write-Host "Testing CommandEditDialog fixes..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. Press 'E' to test Edit dialog"
Write-Host "2. Type some text in the fields"
Write-Host "3. Press ESC to cancel (should work immediately)"
Write-Host "4. Check that borders are properly aligned"
Write-Host "5. Press 'Q' to quit"
Write-Host ""

# Run the command library
[CommandLibrary]::Run()
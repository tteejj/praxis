#!/usr/bin/env pwsh

# Test the new simplified dialog
. "$PSScriptRoot/Screens/SimpleStartupDialog.ps1"

Write-Host "Testing simplified dialog..." -ForegroundColor Green
Test-SimpleStartupDialog
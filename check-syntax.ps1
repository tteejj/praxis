#!/usr/bin/env pwsh

# Check syntax of TimeEntryScreen
try {
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        "$PSScriptRoot/Screens/TimeEntryScreen.ps1",
        [ref]$null,
        [ref]$null
    )
    Write-Host "TimeEntryScreen.ps1 syntax is valid" -ForegroundColor Green
} catch {
    Write-Host "Syntax error in TimeEntryScreen.ps1: $_" -ForegroundColor Red
}
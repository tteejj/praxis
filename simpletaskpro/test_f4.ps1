#!/usr/bin/env pwsh

# Simple test for F4 key functionality
Write-Host "Testing SimpleTaskPro F4 functionality..."
Write-Host "1. Starting the application..."
Write-Host "2. Press F4 to switch to time entry mode"
Write-Host "3. Look for debug output showing counts"
Write-Host ""

# Import necessary assemblies
Add-Type -AssemblyName System.Console

# Start the application in a way that allows key input
& "./SimpleTaskPro.ps1"
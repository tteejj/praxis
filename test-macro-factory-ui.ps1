#!/usr/bin/env pwsh

# Test the VisualMacroFactoryScreen in PRAXIS to verify actions are visible
param([switch]$LoadOnly)

# Provide instruction to user
Write-Host "This will start PRAXIS. To test the Macro Factory:" -ForegroundColor Cyan
Write-Host "1. Press '7' to go to Macro Factory tab" -ForegroundColor Yellow  
Write-Host "2. Check if the left pane shows 4 actions:" -ForegroundColor Yellow
Write-Host "   - 📊 Summarization" -ForegroundColor Green
Write-Host "   - ⚙️ Append Calculated Field" -ForegroundColor Green
Write-Host "   - 📋 Export to Excel" -ForegroundColor Green  
Write-Host "   - 🔧 Custom IDEA@ Command" -ForegroundColor Green
Write-Host "3. Test if keyboard shortcuts work:" -ForegroundColor Yellow
Write-Host "   - F5 should trigger preview" -ForegroundColor Green
Write-Host "   - Ctrl+S should trigger save" -ForegroundColor Green
Write-Host "   - Ctrl+N should trigger new macro" -ForegroundColor Green
Write-Host "4. Press Q to quit when done testing" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting PRAXIS..." -ForegroundColor Green

# Start PRAXIS
. "$PSScriptRoot/Start.ps1"
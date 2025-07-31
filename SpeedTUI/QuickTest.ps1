#!/usr/bin/env pwsh
# Quick test to debug display issues

# Load the framework
. "$PSScriptRoot/Start.ps1"

Write-Host "Testing simple display..." -ForegroundColor Green

# Create a simple label test
$label = [Label]::new("Hello SpeedTUI!")
$label.SetBounds(0, 0, 20, 1)

# Create a simple buffer test
Write-Host "Creating render buffer..." -ForegroundColor Yellow
$terminal = [Terminal]::GetInstance()
$terminal.UpdateDimensions()

Write-Host "Terminal size: $($terminal.Width) x $($terminal.Height)" -ForegroundColor Cyan

# Test direct console output
[Console]::Clear()
[Console]::SetCursorPosition(5, 5)
Write-Host "=== SpeedTUI Framework Demo ===" -ForegroundColor Cyan
[Console]::SetCursorPosition(5, 7)
Write-Host "PROJECTS:" -ForegroundColor Yellow
[Console]::SetCursorPosition(7, 8)
Write-Host "✓ Project Alpha    [████████░░] 75%" -ForegroundColor Green
[Console]::SetCursorPosition(7, 9)
Write-Host "⚠ Project Beta     [██░░░░░░░░] 20%" -ForegroundColor Yellow
[Console]::SetCursorPosition(7, 10)
Write-Host "✓ Project Gamma    [██████████] 100%" -ForegroundColor Green
[Console]::SetCursorPosition(7, 11)
Write-Host "⏸ Project Delta    [████░░░░░░] 45%" -ForegroundColor Blue

[Console]::SetCursorPosition(5, 13)
Write-Host "TASKS:" -ForegroundColor Green
[Console]::SetCursorPosition(7, 14)
Write-Host "Design UI mockups          | In Progress  | High" -ForegroundColor White
[Console]::SetCursorPosition(7, 15)
Write-Host "Implement data layer       | Completed    | High" -ForegroundColor Green
[Console]::SetCursorPosition(7, 16)
Write-Host "Write unit tests           | Pending      | Medium" -ForegroundColor Yellow

[Console]::SetCursorPosition(5, 18)
Write-Host "Static display test - Press Enter to continue..." -ForegroundColor Gray
Read-Host

Write-Host "Test completed!" -ForegroundColor Green
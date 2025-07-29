#!/usr/bin/env pwsh
# Minimal test to diagnose border issues

. ./Start.ps1 -NoStart

# Create a minimal ProjectsScreen with just the grid
$testScreen = [ProjectsScreen]::new()
$testScreen.Initialize($global:ServiceContainer)

# Simplify to just show the border
$testScreen.ProjectGrid.ShowBorder = $true
$testScreen.ProjectGrid.BorderType = [BorderType]::Rounded

# Position it at top of screen with some margin
$testScreen.SetBounds(2, 2, 60, 20)

# Clear screen
[Console]::Clear()

# Render just the screen
$rendered = $testScreen.Render()
[Console]::Write($rendered)

# Wait for key
Write-Host "`n`nPress any key to test without border..."
[Console]::ReadKey($true) | Out-Null

# Test without border
$testScreen.ProjectGrid.ShowBorder = $false
[Console]::Clear()
$rendered = $testScreen.Render()
[Console]::Write($rendered)

Write-Host "`n`nPress any key to test with Single border..."
[Console]::ReadKey($true) | Out-Null

# Test with Single border
$testScreen.ProjectGrid.ShowBorder = $true
$testScreen.ProjectGrid.BorderType = [BorderType]::Single
[Console]::Clear()
$rendered = $testScreen.Render()
[Console]::Write($rendered)

Write-Host "`n`nPress any key to exit..."
[Console]::ReadKey($true) | Out-Null
#!/usr/bin/env pwsh
# Test FileBrowser focus behavior

param(
    [switch]$Debug
)

# Set debug mode
if ($Debug) {
    $global:PraxisDebug = $true
}

# Set up paths
$script:PraxisRoot = $PSScriptRoot
$global:PraxisRoot = $PSScriptRoot
Set-Location $script:PraxisRoot

# Load required files
. ./Core/ServiceContainer.ps1
. ./Core/VT100.ps1
. ./Services/Logger.ps1
. ./Services/ThemeManager.ps1
. ./Base/UIElement.ps1
. ./Base/Container.ps1
. ./Base/Screen.ps1
. ./Components/FastFileTree.ps1
. ./Screens/FileBrowserScreen.ps1

# Create services
$global:ServiceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$global:ServiceContainer.Register("Logger", $logger)
$theme = [ThemeManager]::new()
$global:ServiceContainer.Register("ThemeManager", $theme)

Write-Host "Testing FileBrowser Focus..." -ForegroundColor Cyan

# Create FileBrowserScreen
$screen = [FileBrowserScreen]::new()
$screen.Initialize($global:ServiceContainer)
$screen.SetBounds(0, 0, 80, 25)

Write-Host "`nScreen created and initialized" -ForegroundColor Green
Write-Host "FileTree exists: $($screen.FileTree -ne $null)" -ForegroundColor Gray
Write-Host "FileTree IsFocusable: $($screen.FileTree.IsFocusable)" -ForegroundColor Gray
Write-Host "FileTree HasFocus: $($screen.FileTree.HasFocus)" -ForegroundColor Gray

# Activate the screen
Write-Host "`nActivating screen..." -ForegroundColor Cyan
$screen.OnActivated()

Write-Host "After activation:" -ForegroundColor Green
Write-Host "FileTree HasFocus: $($screen.FileTree.HasFocus)" -ForegroundColor Gray

# Find what has focus
$focused = $screen.FindFocused()
if ($focused) {
    Write-Host "Focused element: $($focused.GetType().Name)" -ForegroundColor Green
} else {
    Write-Host "No element has focus!" -ForegroundColor Red
}

# Try to manually focus the FileTree
Write-Host "`nManually focusing FileTree..." -ForegroundColor Cyan
$screen.FileTree.Focus()
Write-Host "FileTree HasFocus: $($screen.FileTree.HasFocus)" -ForegroundColor Gray

# Test input handling
Write-Host "`nTesting input handling..." -ForegroundColor Cyan
$downKey = [System.ConsoleKeyInfo]::new([char]0, [System.ConsoleKey]::DownArrow, $false, $false, $false)
$handled = $screen.FileTree.HandleInput($downKey)
Write-Host "Down arrow handled: $handled" -ForegroundColor Gray

# Check the full focus chain
Write-Host "`nChecking focus chain:" -ForegroundColor Cyan
$current = $screen
$level = 0
while ($current) {
    $indent = "  " * $level
    Write-Host "$indent$($current.GetType().Name) - HasFocus: $($current.HasFocus)" -ForegroundColor Gray
    if ($current -is [Container]) {
        foreach ($child in $current.Children) {
            $childIndent = "  " * ($level + 1)
            Write-Host "$childIndent$($child.GetType().Name) - HasFocus: $($child.HasFocus), IsFocusable: $($child.IsFocusable)" -ForegroundColor DarkGray
        }
    }
    break
}

# Flush logger
$logger.Flush()

Write-Host "`nCheck log for details: $($logger.LogPath)" -ForegroundColor Cyan